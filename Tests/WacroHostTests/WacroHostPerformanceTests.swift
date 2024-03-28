import XCTest
@testable import WacroPluginHost
import Foundation

final class WacroHostPerformanceTests: XCTestCase {
    func testWasmKitPerformance1() throws {
        measurePerformance(of: WasmKitMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: WasmKitMacroRunner.self, iterations: 1)
        }
    }

    func testWasmKitPerformance5() throws {
        measurePerformance(of: WasmKitMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: WasmKitMacroRunner.self, iterations: 5)
        }
    }

    func testWebKitPerformance1() throws {
        measurePerformance(of: WebMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: WebMacroRunner.self, iterations: 1)
        }
    }

    func testWebKitPerformance5() throws {
        measurePerformance(of: WebMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: WebMacroRunner.self, iterations: 5)
        }
    }

    private func measurePerformance<Runner: MacroRunner>(
        of runner: Runner.Type,
        iterations: Int
    ) {
        let expectation = expectation(description: "\(runner) runner should run")
        Task {
            let runner = try! await Runner(wasm: TestConstants.wasm)
            for _ in 0..<iterations {
                _ = try! await runner.handle(TestConstants.input)
            }
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
}
