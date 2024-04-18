import WASI
import WasmTypes
import Foundation

package protocol WasmMacroRunner: MacroRunner {
  associatedtype GuestMemoryType: GuestMemory
  var memory: GuestMemoryType { get }

  init(wasm: Data, bridge: WASIBridgeToHost) async throws

  func invoke(_ method: String, _ args: [UInt32]) throws -> [UInt32]
}

extension WasmMacroRunner {
  package init(data: Data) async throws {
    let bridge = try WASIBridgeToHost()
    try await self.init(wasm: data, bridge: bridge)
    _ = try invoke("_start", [])
  }

  package func handle(_ json: String) async throws -> String {
    let jsonLen = UInt32(json.count)
    let inAddr = try invoke("wacro_malloc", [jsonLen])[0]
    let rawInAddr = UnsafeGuestPointer<UInt8>(memorySpace: memory, offset: inAddr)
    _ = UnsafeGuestBufferPointer(baseAddress: rawInAddr, count: jsonLen)
      .withHostPointer { $0.initialize(from: json.utf8) }

    let outAddr = try invoke("wacro_parse", [inAddr, jsonLen])[0]
    let outLen = UnsafeGuestPointer<UInt32>(memorySpace: memory, offset: outAddr).pointee
    let outBase = UnsafeGuestPointer<UInt8>(memorySpace: memory, offset: outAddr + 4)
    let out = UnsafeGuestBufferPointer(baseAddress: outBase, count: outLen)
      .withHostPointer { String(decoding: $0, as: UTF8.self) }

    _ = try invoke("wacro_free", [outAddr])

    return out
  }
}
