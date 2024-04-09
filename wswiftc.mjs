#!/usr/bin/env node

// Usage: this is a drop-in replacement for swiftc that supports
// raw wacro modules as plugins. For example,
// ./wswiftc.mjs file.swift -load-plugin-executable ExampleRaw.wasm#ExampleRaw

import { spawn, spawnSync } from 'child_process';
import { createHash } from 'crypto';
import { link, mkdir, readFile, rm, stat } from 'fs/promises';
import { tmpdir } from 'os';

const tmp = await tmpdir()
const wacroTmp = `${tmp}/wacro`;

async function prepareForwarder() {
    // a swift compiler plugin that forwards requests to us
    // via fds so that we can talk to swiftc
    const forwarder = `
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <libgen.h>

int main(int argc, char **argv) {
    int index = atoi(basename(argv[0])) - 1;
    FILE *adhoc_input = fdopen(3 + index * 2, "w");
    assert(adhoc_input != NULL);
    FILE *adhoc_output = fdopen(4 + index * 2, "r");
    assert(adhoc_output != NULL);
    char *buf = NULL;
    size_t buf_size = 0;
    while (1) {
        for (int i = 0; i < 2; i++) {
            FILE *in = i ? adhoc_output : stdin;
            FILE *out = i ? stdout : adhoc_input;
            uint64_t len;
            if (fread(&len, sizeof(len), 1, in) != 1) return 0;
            if (buf_size < len) { assert(buf = realloc(buf, len)); buf_size = len; }
            assert(fread(buf, len, 1, in) == 1);
            assert(fwrite(&len, sizeof(len), 1, out) == 1);
            assert(fwrite(buf, len, 1, out) == 1);
            fflush(out);
        }
    }
    free(buf);
    return 0;
}
`;
    const forwarderHash = createHash('sha256').update(forwarder).digest('hex');
    const forwarderOut = `${wacroTmp}/${forwarderHash}`;
    if (await stat(forwarderOut).catch(() => null) !== null) return forwarderOut;
    await rm(wacroTmp, { recursive: true, force: true });
    await mkdir(`${wacroTmp}/links`, { recursive: true });
    spawnSync('cc', ['-x', 'c', '-', '-O2', '-o', forwarderOut], {
        input: forwarder,
        stdio: ['pipe', 'inherit', 'inherit']
    })
    return forwarderOut;
}

async function prepareForwarders(n) {
    const out = await prepareForwarder();
    const lastLink = `${wacroTmp}/links/${n}`
    if (await stat(lastLink).catch(() => null) !== null) return;
    await Promise.all(Array.from({ length: n }).map(async (_, i) => {
        const dest = `${wacroTmp}/links/${i + 1}`;
        // *hard*link to avoid resolving argv[0] to the base file
        await link(out, dest).catch(() => {});
    }));
}

async function makePlugin(path) {
    const data = await readFile(path);
    const mod = await WebAssembly.compile(data);
    // stub WASI imports
    const imports = WebAssembly.Module.imports(mod)
        .filter(x => x.module === "wasi_snapshot_preview1")
        .map(x => [x.name, () => {}]);
    const instance = await WebAssembly.instantiate(mod, {
        wasi_snapshot_preview1: Object.fromEntries(imports)
    });
    const api = instance.exports;
    const mem = api.memory;
    api._start();
    return (data) => {
        const inAddr = api.wacro_malloc(data.length);
        new Uint8Array(mem.buffer, inAddr, data.length).set(data);
        const outAddr = api.wacro_parse(inAddr, data.length);
        const lenOut = new Uint32Array(mem.buffer, outAddr, 1)[0];
        return new Uint8Array(mem.buffer, outAddr + 4, lenOut);
    }
}

async function runCompiler(args, plugins) {
    const swift = spawn('swiftc', args, {
        stdio: ['inherit', 'inherit', 'inherit', ...plugins.flatMap(_ => ['pipe', 'pipe'])]
    })
    const allRequests = plugins.map((_, i) => swift.stdio[3 + i * 2]);
    const allResponses = plugins.map((_, i) => swift.stdio[4 + i * 2]);

    const pendings = new Map();

    function eat(size, stream) {
        pendings.get(stream).splice(0, size);
    }

    async function readAsync(size, stream, peek = false) {
        let pending = pendings.get(stream);
        if (pending === undefined) pendings.set(stream, pending = []);
        while (pending.length < size) {
            const read = await Promise.race([
                new Promise(r => stream.once('data', r)),
                new Promise(r => stream.once('end', r)),
            ])
            if (!read) return null;
            pending.push(...read);
        }
        const out = Uint8Array.from(pending.slice(0, size));
        if (!peek) pending.splice(0, size);
        return out;
    }

    const writeAsync = (data, stream) => new Promise(r => stream.write(data, r));

    const readAnyAsync = (size) => Promise.race(allRequests.map(async (s, i) => {
        const data = await readAsync(size, s, true);
        return data === null ? null : [data, i];
    }));

    /** @type {readonly [Uint8Array, number] | null} */ let next;
    while ((next = await readAnyAsync(8)) !== null) {
        const [lenRaw, index] = next;
        eat(8, allRequests[index]);
        const len = Number(new DataView(lenRaw.buffer).getBigUint64(0, true));
        const data = await readAsync(len, allRequests[index]);
        const outArr = plugins[index](data);
        const buf = Buffer.alloc(8);
        buf.writeBigUInt64LE(BigInt(outArr.length), 0);
        await writeAsync(buf, allResponses[index]);
        await writeAsync(outArr, allResponses[index]);
    }
}

const input = process.argv.slice(2);
const moduleIndices = input.flatMap((x, i) => x === "-load-plugin-executable" && input[i+1].includes(".wasm") ? [i + 1] : [])
const plugins = moduleIndices.map((i) => input[i].split('#'));
const args = [...input];
moduleIndices.forEach((mi, i) => args[mi] = `${wacroTmp}/links/${i+1}#${plugins[i][1]}`);

const [pluginFuncs] = await Promise.all([
    Promise.all(plugins.map(([p]) => makePlugin(p))),
    prepareForwarders(plugins.length)
]);
await runCompiler(args, pluginFuncs);
