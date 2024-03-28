# Wacro

Wacro (**W**ebAssembly M**acro**s) is a proof-of-concept implementation of the _Building Swift Macros with WebAssembly_ proposal [pitched](https://www.swift.org/gsoc2024/) for GSoC 2024.

As of today, Wacro already allows library authors to build macros in WebAssembly and users to consume them like any other Swift library: see the `Example/` folder for details. However there are currently some performance pitfalls — which can be fixed, albeit requiring implementation within the compiler/SwiftPM itself.

**Wacro is not** a GSoC submission: it merely exists to show that this is possible (without even modifying the compiler or SwiftPM!) but a real-world implementation _should_ probably be integrated into the compiler and SwiftPM to improve usability and performance.

## Why?

🐇 Swift Macros as they currently stand are [notoriously slow](https://forums.swift.org/t/compilation-extremely-slow-since-macros-adoption/67921) to compile. This is because most macros depend on `swift-syntax` (Swift's syntax parsing library) in source form, which in turn is a really large library that takes a long time to build.
- swift-syntax is not API/ABI stable, which means this problem can't be solved by pre-compiling it for build host machines.
- Swift itself is not ABI stable on any platform except Darwin. Therefore even if swift-syntax had a stable ABI (seemingly unlikely as this is right now), it would only solve build times on macOS.  
- ✅ By instead shipping macros as WebAssembly binaries, the binaries can be built to statically link a compiled build of swift-syntax. Since WebAssembly is agnostic to the host platform, macro authors can ship one pre-compiled binary that runs on any host machine!

🤝 SwiftPM currently only permits linking to a single version of a package. So if two macros depend on conflicting versions of swift-syntax, SwiftPM will refuse to build.
- ✅ With WebAssembly's "shared-nothing" model, WebAssembly-based macros can link to entirely different versions of swift-syntax and be used by the a client without conflict.

🔐 Swift Macros are intended to be "pure" and not have access to system resources. This is currently realized on macOS via the system sandbox. However, macros are (to my knowledge) not sandboxed on Linux; while this could be somewhat remedied by using [namespaces](https://en.wikipedia.org/wiki/Linux_namespaces), it may require considerable effort and moreover namespaces are widely considered *not* to be a security boundary.
- ✅ Meanwhile, WebAssembly is entirely sandboxed by default, with the possibility to provide access to additional resources using a powerful [capability-based](https://github.com/bytecodealliance/wasmtime/blob/d38d387a1365cc2d809718eca135d138ac754469/docs/WASI-capabilities.md) model.

## How?

Wacro breaks down macros into two phases:

1. **Raw Macro**: The macro source is built into a WASM binary by the macro author, called the **raw** macro. This is just like a regular macro but 1) it is an `.executableTarget` instead of a `.macro` and 2) it depends on `WacroPluginRaw` instead of `SwiftCompilerPlugin`. The binary is checked into source control (ideally one could point to a remote resource instead, but this may require buy-in from SwiftPM.)
2. **Host Macro**: This is the "real" macro consumed by clients. It is a bare-bones `.macro` target where the macro implements `WacroPluginHost`. The only requirement for this conformance is a `providingLibrary: URL` that points to the raw macro's file path.

When the host macro is invoked, `WacroPluginHost` spins up a WebAssembly "runner" which talks to the raw macro to perform the actual work.

## WebAssembly Compilation

With Swift 6.0, support for WASM and WASI have now been [upstreamed](https://forums.swift.org/t/stdlib-and-runtime-tests-for-wasm-wasi-now-available-on-swift-ci/70385). This means that a vanilla Swift 6.0 toolchain can build WASI binaries out of the box given a WASI SDK. 

## WebAssembly Runners

TODO

## Try it Out

The `Example/` folder contains a fully functional Wacro-based macro. I chose not to check in the wasm source, which means you'll need to build both the wasm and the client:

### Building the raw macro

1. Install a WASM-compatible toolchain from [swift.org/download](https://www.swift.org/download/). A recent `main` snapshot should definitely work, and the 6.0 snapshots might also work (untested).
2. Install a WASI SDK: see <https://book.swiftwasm.org/getting-started/setup.html#experimental-swift-sdk>
3. `cd Example/` in a checkout of this repo and run `make wasm`. 

You should see the file `/Example/ExampleRaw.wasm.dylib` after running these steps. This is a bona-fide WebAssembly module; the `dylib` extension is merely to pacify the macOS sandbox. 

### Building the host

(You can switch back to a production toolchain for this)

1. Change into the `Example/` directory again.
2. Run `make client`. If you're on macOS and want to use the WebKit runner (faster), use `make client WK=1`.
3. That's all! You can now run the produced executable at `.build/debug/ExampleClient`.

Since compiling the host follows standard procedure, you can build and run with Xcode as well. Just open `Example/Package.swift` in Xcode and build `ExampleClient`.

## Performance

**Note**: this section is about _build time_ performance. Runtime performance will be identical to a typical macro. The WebAssembly execution process is build-time-only.

TODO
