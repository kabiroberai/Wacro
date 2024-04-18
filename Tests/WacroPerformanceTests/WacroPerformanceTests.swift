import XCTest
import WacroPluginHost
import WacroTestSupport
import JavaScriptCore

@_silgen_name("JSSynchronousGarbageCollectForDebugging")
private func JSSynchronousGarbageCollectForDebugging(_ context: JSContextRef)

final class WacroPerformanceTests: XCTestCase {
    func testJSPerformanceCold() throws {
        measurePerformance(of: JSCMacroRunner.self, iterations: 1)
        measure {
            measurePerformance(of: JSCMacroRunner.self, iterations: 1)
        }
    }

    func testJSPerformanceHot() async throws {
        measurePerformance(of: JSCMacroRunner.self, iterations: 1)
        measure {
            // baseline: 25.4 ms per handle()
            measurePerformance(of: JSCMacroRunner.self, iterations: 100)
        }
    }

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
            let runner = try! await Runner(data: TestConstants.wasm)
            for _ in 0..<iterations {
                _ = try! await runner.handle(TestConstants.input)
            }
            if let runner = runner as? JSCMacroRunner {
                let ctx = runner.api.context.jsGlobalContextRef
                for _ in 0..<10 { JSSynchronousGarbageCollectForDebugging(ctx!) }
//                let len = runner.api.objectForKeyedSubscript("memory").objectForKeyedSubscript("buffer").objectForKeyedSubscript("byteLength")
//                print(len)
            }
            expectation.fulfill()
        }
        wait(for: [expectation])
    }
}
