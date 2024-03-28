import Foundation

var onRequest: ((Data) -> Data)? = nil

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
public func macroParse(_ message: UnsafeMutablePointer<UInt8>?, _ size: UInt32) -> UnsafeMutablePointer<UInt8>? {
    let input = Data(bytesNoCopy: message!, count: Int(size), deallocator: .custom { p, _ in p.deallocate() })
    let output = if let onRequest { onRequest(input) } else { fatalError("onRequest == nil") }

    let outPointer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: 4 + output.count)
    var count = UInt32(output.count).littleEndian
    withUnsafeBytes(of: &count) {
        _ = outPointer.initialize(from: $0)
    }
    _ = outPointer[4...].initialize(from: output)

    return outPointer.baseAddress
}
