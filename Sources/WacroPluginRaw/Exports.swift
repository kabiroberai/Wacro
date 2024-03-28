import Foundation

var onRequest: ((Data) -> Data)? = nil

#if compiler(>=6.0) && os(WASI)

@_expose(wasm, "wacro_malloc")
@_cdecl("wacro_malloc")
public func macroMalloc(_ size: UInt32) -> UnsafeMutablePointer<UInt8> {
    UnsafeMutablePointer<UInt8>.allocate(capacity: Int(size))
}

@_expose(wasm, "wacro_free")
@_cdecl("wacro_free")
public func macroFree(_ pointer: UnsafeMutablePointer<UInt8>?) {
    pointer?.deallocate()
}

// transfers ownership of message to callee.
// returned pointer is pascal-style string with a 32-bit length prefix.
// caller must free returned pointer.
@_expose(wasm, "wacro_parse")
@_cdecl("wacro_parse")
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

#endif
