// loosely based on
// https://github.com/apple/swift-syntax/blob/cfd0487a9c70bd91935d7ea13ad4410cc4569cf1/Sources/SwiftCompilerPlugin/CompilerPlugin.swift
// but wasm compatible

#if compiler(>=6.0) && os(WASI)

#if swift(>=6.0)
public import SwiftSyntaxMacros
private import Foundation
private import SwiftCompilerPluginMessageHandling
#else
import SwiftSyntaxMacros
import Foundation
import SwiftCompilerPluginMessageHandling
#endif

public protocol WacroPluginRaw {
    init()

    var providingMacros: [Macro.Type] { get }
}

struct MacroProviderAdapter<Plugin: WacroPluginRaw>: PluginProvider {
    let types: [String: Macro.Type]
    init(plugin: Plugin) {
        types = Dictionary(plugin.providingMacros.map { type in
            let fullName = String(reflecting: type)
            let typeName = fullName.split(separator: ".").dropFirst().joined(separator: ".")
            return (typeName, type)
        }) { $1 }
    }
    func resolveMacro(moduleName: String, typeName: String) -> Macro.Type? {
        types[typeName]
    }
}

extension WacroPluginRaw {
    /// Main entry point of the plugin
    public static func main() throws {
        // this behaves a bit differently from the bona fide CompilerPlugin.main.
        // we don't use a loop/stdio (to avoid relying on WASI), instead our
        // entrypoint merely defines onRequest so that it can accept a single request
        // and return a single response by invoking the WacroPluginRaw implementor.
        //
        // we then export wacro_parse which the host can call to invoke onRequest.

        let connection = PluginHostConnection()
        let provider = MacroProviderAdapter(plugin: Self())
        let impl = CompilerPluginMessageHandler(connection: connection, provider: provider)
        onRequest = { input in
            connection.incoming = input
            // this will receive `input` from our connection class, write the output to
            // `connection.outgoing`, and then determine that there are no more messages
            // and end the "loop".
            try! impl.main()
            return connection.outgoing
        }
    }
}

class PluginHostConnection: MessageConnection {
    var incoming: Data?
    var outgoing = Data()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func sendMessage<TX: Encodable>(_ message: TX) throws {
        outgoing = try encoder.encode(message)
    }

    func waitForNextMessage<RX: Decodable>(_ ty: RX.Type) throws -> RX? {
        guard let incoming else { return nil }
        self.incoming = nil
        return try decoder.decode(RX.self, from: incoming)
    }
}

#endif
