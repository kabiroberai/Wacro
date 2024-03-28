import Foundation
import WebKit

protocol MacroRunner {
    init(wasm: Data) async throws

    func handle(_ json: String) async throws -> String
}

@MainActor final class WebMacroRunner: MacroRunner {
    private let webView: WKWebView

    private init<Chunks: AsyncSequence>(_ data: Chunks) async throws where Chunks.Element == Data {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(SchemeHandler { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                "access-control-allow-origin": "*",
                "content-type": "application/wasm"
            ])!
            return (data, response)
        }, forURLScheme: "wasm-runner-data")
        webView = WKWebView(frame: .zero, configuration: configuration)
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

        _ = try await webView.callAsyncJavaScript(
            """
            const mod = await WebAssembly.compileStreaming(fetch("wasm-runner-data://"));
            const imports = WebAssembly.Module.imports(mod)
                .filter(x => x.module === "wasi_snapshot_preview1")
                .map(x => [x.name, () => {}])
            wasm = await WebAssembly.instantiate(mod, {
                wasi_snapshot_preview1: Object.fromEntries(imports)
            });
            enc = new TextEncoder();
            dec = new TextDecoder();
            wasm.exports._start();
            """,
            contentWorld: .defaultClient
        )
    }

    convenience init(wasm: Data) async throws {
        try await self.init(AsyncStream {
            $0.yield(wasm)
            $0.finish()
        })
    }

    func handle(_ json: String) async throws -> String {
        let utf8Length = json.utf8.count
        return try await webView.callAsyncJavaScript("""
        const inAddr = wasm.exports.macro_malloc(\(utf8Length));
        const mem = wasm.exports.memory.buffer;
        const arr = new Uint8Array(mem, inAddr, \(utf8Length));
        enc.encodeInto(json, arr);
        const outAddr = wasm.exports.macro_parse(inAddr, \(utf8Length));
        const len = new Uint32Array(mem, outAddr)[0];
        const outArr = new Uint8Array(mem, outAddr + 4, len);
        const text = dec.decode(outArr);
        wasm.exports.macro_free(outAddr);
        return text;
        """, arguments: ["json": json], contentWorld: .defaultClient) as! String
    }
}

private final class SchemeHandler<Chunks: AsyncSequence>: NSObject, WKURLSchemeHandler where Chunks.Element == Data {
    public typealias RequestHandler<Output> = (URLRequest) async throws -> (Output, URLResponse)

    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private let onRequest: RequestHandler<Chunks>

    // 16 KB
    public static var defaultChunkSize: Int { 16 << 10 }

    public init(onRequest: @escaping RequestHandler<Chunks>) {
        self.onRequest = onRequest
    }

    public func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        tasks[ObjectIdentifier(task)] = Task {
            var err: Error?
            do {
                let (stream, response) = try await onRequest(task.request)
                try Task.checkCancellation()
                task.didReceive(response)
                for try await data in stream {
                    try Task.checkCancellation()
                    task.didReceive(data)
                }
            } catch {
                err = error
            }
            guard !Task.isCancelled else { return }
            if let err {
                task.didFailWithError(err)
            } else {
                task.didFinish()
            }
        }
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }
}
