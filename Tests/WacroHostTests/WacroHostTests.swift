import XCTest
@testable import WacroPluginHost
import Foundation

final class WacroHostTests: XCTestCase {
    func testWebRunner() async throws {
        let runner = try await WebMacroRunner(wasm: TestConstants.wasm)
        let output = try await runner.handle(TestConstants.input)
        XCTAssert(output.hasPrefix("{"), "Expected output to be a JSON object. Got: \(output)")
    }

    func testWasmKitRunner() async throws {
        let runner = try WasmKitMacroRunner(wasm: TestConstants.wasm)
        let output = try runner.handle(TestConstants.input)
        XCTAssert(output.hasPrefix("{"), "Expected output to be a JSON object. Got: \(output)")
    }
}

enum TestConstants {
    static let input = #"{"getCapability":{"capability":{"protocolVersion":1}}}"#

    static let wasm: Data = {
        let path = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(components: "..", "..")
            .appending(components: "Example", "ExampleRaw.wasm.dylib")
        return try! Data(contentsOf: path)
    }()
}
