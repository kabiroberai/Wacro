import XCTest
import WacroTestSupport
@testable import WacroPluginHost

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
