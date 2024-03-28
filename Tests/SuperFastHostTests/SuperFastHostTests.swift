import XCTest
@testable import SuperFastPluginHost
import Foundation
import SwiftCompilerPluginMessageHandling

final class SuperFastHostTests: XCTestCase {
    func testRunner() async throws {
        let rootPath = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(components: "..", "..")
        let data = try Data(contentsOf: rootPath.appending(path: "Example/.build/wasm32-unknown-wasi/release/ExampleRaw.wasm"))
        let runner = try await WebMacroRunner(wasm: data)
        let encoder = JSONEncoder()
        let msg = HostToPluginMessage.getCapability(capability: PluginMessage.HostCapability(protocolVersion: 1))
        let json = String(decoding: try encoder.encode(msg), as: UTF8.self)
        let output = try await runner.handle(json)
        let result = try JSONDecoder().decode(PluginToHostMessage.self, from: Data(output.utf8))
        switch result {
        case .getCapabilityResult:
            break
        default:
            XCTFail("Expected getCapabilityResult response. Got: \(result)")
        }
    }
}
