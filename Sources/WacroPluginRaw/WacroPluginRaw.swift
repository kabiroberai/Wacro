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
// NOTE: This basic plugin mechanism is mostly copied from
// https://github.com/apple/swift-package-manager/blob/main/Sources/PackagePlugin/Plugin.swift

import SwiftSyntaxMacros

#if swift(>=5.11)
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
    let qualifedName = "\(typeName)"

    for type in providingMacros {
      // FIXME: Is `String(reflecting:)` stable?
      // Getting the module name and type name should be more robust.
      let name = String(reflecting: type)
      if name.split(separator: ".").dropFirst().joined(separator: ".") == qualifedName {
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

  /// Main entry point of the plugin — sets up a communication channel with
  /// the plugin host and runs the main message loop.
  public static func main() throws {
    // Open a message channel for communicating with the plugin host.
    let connection = PluginHostConnection()

    // Handle messages from the host until the input stream is closed,
    // indicating that we're done.
    let provider = MacroProviderAdapter(plugin: Self())
    let impl = CompilerPluginMessageHandler(connection: connection, provider: provider)
    onRequest = { input in
        connection.incoming = input
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

// transfers ownership of message to callee
// returned pointer is pascal-style string
// caller must free returned pointer
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
