import Foundation

internal struct PluginHostConnection {
  fileprivate let inputStream: FileHandle
  fileprivate let outputStream: FileHandle

  init(inputStream: FileHandle, outputStream: FileHandle) {
    self.inputStream = inputStream
    self.outputStream = outputStream
  }

  func sendMessage(_ message: String) throws {
    let payload = Data(message.utf8)

    // Write the header (a 64-bit length field in little endian byte order).
    var count = UInt64(payload.count).littleEndian
    let header = Swift.withUnsafeBytes(of: &count) { Data($0) }
    precondition(header.count == 8)

    // Write the header and payload.
    try outputStream._write(contentsOf: header)
    try outputStream._write(contentsOf: payload)
  }

  func waitForNextMessage() throws -> String? {
    // Read the header (a 64-bit length field in little endian byte order).
    guard
      let header = try inputStream._read(upToCount: 8),
      header.count != 0
    else {
      return nil
    }
    guard header.count == 8 else {
      throw PluginMessageError.truncatedHeader
    }

    // Decode the count.
    let count = header.withUnsafeBytes {
      UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self))
    }
    guard count >= 2 else {
      throw PluginMessageError.invalidPayloadSize
    }

    // Read the JSON payload.
    guard
      let payload = try inputStream._read(upToCount: Int(count)),
      payload.count == count
    else {
      throw PluginMessageError.truncatedPayload
    }

    // Decode and return the message.
    return String(decoding: payload, as: UTF8.self)
  }

  enum PluginMessageError: Swift.Error {
    case truncatedHeader
    case invalidPayloadSize
    case truncatedPayload
  }
}

private extension FileHandle {
  func _write(contentsOf data: Data) throws {
    if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
      return try self.write(contentsOf: data)
    } else {
      return self.write(data)
    }
  }

  func _read(upToCount count: Int) throws -> Data? {
    if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
      return try self.read(upToCount: count)
    } else {
      return self.readData(ofLength: 8)
    }
  }
}
