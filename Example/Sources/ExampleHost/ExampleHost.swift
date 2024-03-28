import WacroPluginHost
import Foundation

@main struct Host: WacroPluginHost {
    var providingLibrary: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../ExampleRaw.wasm.dylib")
    }
}
