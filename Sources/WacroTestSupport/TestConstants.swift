import Foundation
import WacroPluginHost

package enum TestConstants {
    package static let input = #"""
    {"expandFreestandingMacro":{"macroRole":"expression","discriminator":"random","macro":{"moduleName":"ExampleHost","typeName":"StringifyMacro","name":"StringifyMacro"},"syntax":{"location":{"fileName":"file.swift","column":1,"offset":1,"line":1,"fileID":"file.swift"},"kind":"expression","source":"#stringify(1 + 1)"}}}
    """#

    // assumption: WacroExample is a sibling to the root Wacro dir.
    package static let wasm: Data = {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../WacroExample/ExampleRaw.wasm.dylib")
        return try! Data(contentsOf: path)
    }()
}
