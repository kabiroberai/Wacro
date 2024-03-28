//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

// loosely based on
// https://github.com/apple/swift-syntax/blob/cfd0487a9c70bd91935d7ea13ad4410cc4569cf1/Sources/SwiftCompilerPlugin/CompilerPlugin.swift
// but wasm compatible

import SwiftSyntaxMacros

#if swift(>=6.0)
private import Foundation
private import SwiftCompilerPluginMessageHandling
#else
import Foundation
import SwiftCompilerPluginMessageHandling
#endif

public protocol WacroPluginRaw {
    init()

    var providingMacros: [Macro.Type] { get }
}

extension WacroPluginRaw {
  func resolveMacro(moduleName: String, typeName: String) -> Macro.Type? {
    // NB: we ignore moduleName because it will refer to the host module name
    // whereas the macro's fully qualified name has the "raw" wasm module name
    for type in providingMacros {
      // FIXME: Is `String(reflecting:)` stable?
      // Getting the module name and type name should be more robust.
      let name = String(reflecting: type)
      if name.split(separator: ".").dropFirst().joined(separator: ".") == typeName {
        return type
      }
    }
    return nil
  }

  // @testable
  public func _resolveMacro(moduleName: String, typeName: String) -> Macro.Type? {
    resolveMacro(moduleName: moduleName, typeName: typeName)
  }
}

struct MacroProviderAdapter<Plugin: WacroPluginRaw>: PluginProvider {
  let plugin: Plugin
  init(plugin: Plugin) {
    self.plugin = plugin
  }
  func resolveMacro(moduleName: String, typeName: String) -> Macro.Type? {
    plugin.resolveMacro(moduleName: moduleName, typeName: typeName)
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
    // we then export macro_parse which the host can call to invoke onRequest.

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

public var onRequest: ((Data) -> Data)? = nil

class PluginHostConnection: MessageConnection {
  var incoming: Data?
  var outgoing = Data()

  func sendMessage<TX: Encodable>(_ message: TX) throws {
    outgoing = try JSONEncoder().encode(message)
  }

  func waitForNextMessage<RX: Decodable>(_ ty: RX.Type) throws -> RX? {
    guard let incoming else { return nil }
    self.incoming = nil
    return try JSONDecoder().decode(RX.self, from: incoming)
  }
}

@_expose(wasm, "macro_malloc")
@_cdecl("macro_malloc")
public func macroMalloc(_ size: UInt32) -> UnsafeMutablePointer<UInt8> {
  UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))
}

@_expose(wasm, "macro_free")
@_cdecl("macro_free")
public func macroFree(_ pointer: UnsafeMutablePointer<UInt8>?) {
  pointer?.deallocate()
}

// transfers ownership of message to callee.
// returned pointer is pascal-style string with a 32-bit length prefix.
// caller must free returned pointer.
@_expose(wasm, "macro_parse")
@_cdecl("macro_parse")
public func macroParse(_ message: UnsafeMutablePointer<UInt8>?, _ size: UInt32) -> UnsafeMutablePointer<UInt8> {
  let input = Data(bytesNoCopy: message!, count: Int(size), deallocator: .custom { p, _ in p.deallocate() })
  let output = if let onRequest { onRequest(input) } else { fatalError("onRequest == nil") }

  let outPointer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 8 + output.count)
  var count = UInt32(output.count).littleEndian
  withUnsafeBytes(of: &count) {
    _ = outPointer.initialize(from: $0)
  }
  _ = outPointer[4...].initialize(from: output)

  return outPointer.baseAddress!
}
