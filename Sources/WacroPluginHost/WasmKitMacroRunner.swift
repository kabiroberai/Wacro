#if !WEBKIT_RUNNER

import WasmKit
import WASI
import System
import Foundation

package final class WasmKitMacroRunner: MacroRunner {
    let instance: ModuleInstance
    let runtime: Runtime

    package init(wasm: Data) throws {
        let module = try parseWasm(bytes: Array(wasm))
        let bridge = try WASIBridgeToHost()
        runtime = Runtime(hostModules: bridge.hostModules)
        instance = try runtime.instantiate(module: module)
        _ = try bridge.start(instance, runtime: runtime)
    }

    package func handle(_ json: String) throws -> String {
        let exports = instance.exports
        guard case let .memory(memoryAddr) = exports["memory"] else { fatalError("bad memory") }
        guard case let .function(malloc) = exports["wacro_malloc"] else { fatalError("bad wacro_malloc") }
        guard case let .function(parse) = exports["wacro_parse"] else { fatalError("bad wacro_parse") }
        guard case let .function(free) = exports["wacro_free"] else { fatalError("bad wacro_free") }

        let inAddr = try malloc.invoke([.i32(UInt32(json.utf8.count))], runtime: runtime)[0].i32

        runtime.store.withMemory(at: memoryAddr) { mem in
            mem.data.replaceSubrange(Int(inAddr)..<(Int(inAddr) + json.utf8.count), with: json.utf8)
        }

        let outAddr = try parse.invoke([.i32(inAddr), .i32(UInt32(json.utf8.count))], runtime: runtime)[0].i32
        let str = runtime.store.withMemory(at: memoryAddr) { mem in
            let bytes = Array(mem.data[Int(outAddr)..<(Int(outAddr) + 4)])
            let len =
              (UInt32(bytes[0]) << 0)  |
              (UInt32(bytes[1]) << 8)  |
              (UInt32(bytes[2]) << 16) |
              (UInt32(bytes[3]) << 24)
            let strRaw = mem.data[(Int(outAddr) + 4)...].prefix(Int(len))
            return String(decoding: strRaw, as: UTF8.self)
        }

        _ = try free.invoke([.i32(outAddr)], runtime: runtime)

        return str
    }
}

#endif
