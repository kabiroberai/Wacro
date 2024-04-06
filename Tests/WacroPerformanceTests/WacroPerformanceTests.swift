import XCTest
import WacroPluginHost
import WacroTestSupport

final class WacroPerformanceTests: XCTestCase {
    func testWasmKitPerformanceCold() throws {
        measurePerformance(of: WasmKitMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: WasmKitMacroRunner.self, iterations: 1)
        }
    }

    func testWasmKitPerformanceHot() throws {
        measurePerformance(of: WasmKitMacroRunner.self, iterations: 1)
        measure {
            // baseline: 25.4 ms per handle()
            measurePerformance(of: WasmKitMacroRunner.self, iterations: 100)
        }
    }

    func testWebKitPerformanceCold() throws {
        measurePerformance(of: WebMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: WebMacroRunner.self, iterations: 1)
        }
    }

    func testWebKitPerformanceHot() throws {
        measurePerformance(of: WebMacroRunner.self, iterations: 1)
        measure {
            // baseline: 1.05 ms per handle()
            measurePerformance(of: WebMacroRunner.self, iterations: 1000)
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
