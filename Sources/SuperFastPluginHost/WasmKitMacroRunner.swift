import WasmKit
import WASI
import System
import Foundation

final class WasmKitMacroRunner: MacroRunner {
    let instance: ModuleInstance
    let runtime: Runtime

    init(wasm: Data) async throws {
        let module = try parseWasm(bytes: Array(wasm))
        let bridge = try WASIBridgeToHost()
        runtime = Runtime(hostModules: bridge.hostModules)
        instance = try runtime.instantiate(module: module)
        _ = try bridge.start(instance, runtime: runtime)
    }

    func handle(_ json: String) async throws -> String {
        let exports = instance.exports
        guard case let .memory(memoryAddr) = instance.exports["memory"] else { fatalError("bad memory") }

        guard case let .function(malloc) = exports["macro_malloc"] else { fatalError("bad macro_malloc") }
        guard case let .function(parse) = exports["macro_parse"] else { fatalError("bad macro_parse") }
        guard case let .function(free) = exports["macro_free"] else { fatalError("bad macro_free") }

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
