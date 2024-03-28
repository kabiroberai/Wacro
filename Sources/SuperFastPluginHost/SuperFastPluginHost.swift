import Foundation

protocol MacroRunner {
    init(wasm: Data) async throws

    func handle(_ json: String) async throws -> String
}

public protocol SuperFastPluginHost {
    init()

    var providingLibrary: URL { get }
}

extension SuperFastPluginHost {
    public static func main() async throws {
        let library = Self().providingLibrary
        let runner = try await WasmKitMacroRunner(wasm: Data(contentsOf: library))

        let connection = PluginHostConnection(inputStream: .standardInput, outputStream: .standardOutput)
        while let message = try connection.waitForNextMessage() {
            let output = try await runner.handle(message)
            try connection.sendMessage(output)
        }
    }
}
