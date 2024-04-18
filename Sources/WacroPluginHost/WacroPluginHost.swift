import Foundation

package protocol MacroRunner {
    init(data: Data) async throws

    func handle(_ json: String) async throws -> String
}

public protocol WacroPluginHost {
    init()

    var providingLibrary: URL { get }
}

extension WacroPluginHost {
    public static func main() async throws {
        let runnerType: MacroRunner.Type
        #if WEBKIT_RUNNER
        runnerType = WebMacroRunner.self
        #else
        runnerType = WasmKitMacroRunner.self
        #endif

        let library = Self().providingLibrary
        let runner = try await runnerType.init(data: Data(contentsOf: library))

        let connection = PluginHostConnection(inputStream: .standardInput, outputStream: .standardOutput)
        while let message = try connection.waitForNextMessage() {
            let output = try await runner.handle(message)
            try connection.sendMessage(output)
        }
    }
}
