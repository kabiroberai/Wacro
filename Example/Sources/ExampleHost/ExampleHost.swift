import SuperFastPluginHost
import ExampleHostContainer
import Foundation

@main struct Host: SuperFastPluginHost {
    var providingLibrary: URL {
        exampleURL
    }
}
