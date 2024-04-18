import XCTest
import WacroTestSupport
@testable import WacroPluginHost

final class WacroHostTests: XCTestCase {
    func testWebRunner() async throws {
        let runner = try await WebMacroRunner(data: TestConstants.wasm)
        let output = try await runner.handle(TestConstants.input)
        XCTAssert(output.hasPrefix("{"), "Expected output to be a JSON object. Got: \(output)")
    }

    func testWasmKitRunner() async throws {
        let runner = try await WasmKitMacroRunner(data: TestConstants.wasm)
        let output = try await runner.handle(TestConstants.input)
        XCTAssert(output.hasPrefix("{"), "Expected output to be a JSON object. Got: \(output)")
    }

    func testJSRunner() async throws {
        let runner = try await JSCMacroRunner(data: TestConstants.wasm)
        let output = try await runner.handle(TestConstants.input)
        XCTAssert(output.hasPrefix("{"), "Expected output to be a JSON object. Got: \(output)")
    }
}
