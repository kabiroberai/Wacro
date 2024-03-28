import SuperFastPluginHost
import Foundation

@main struct Host: SuperFastPluginHost {
    var providingLibrary: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../ExampleRaw.wasm.dylib")
    }
}
