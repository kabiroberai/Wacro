#if !WEBKIT_RUNNER

import WasmKit
import Foundation
import WasmKitWASI

package final class WasmKitMacroRunner: WasmMacroRunner {
    let instance: ModuleInstance
    let runtime: Runtime
    package let memory: WasmKitGuestMemory

    package init(wasm: Data, bridge: WASIBridgeToHost) throws {
        let module = try parseWasm(bytes: Array(wasm))
        runtime = Runtime(hostModules: bridge.hostModules)
        instance = try runtime.instantiate(module: module)

        let exports = instance.exports
        guard case let .memory(memoryAddr) = exports["memory"] else { fatalError("bad memory") }
        self.memory = WasmKitGuestMemory(store: runtime.store, address: memoryAddr)
    }

    package func invoke(_ method: String, _ args: [UInt32]) throws -> [UInt32] {
        try runtime.invoke(instance, function: method, with: args.map { .i32($0) }).map(\.i32)
    }
}

#endif
