import Foundation
import WebKit

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

        _ = try await webView.callAsyncJavaScript(
            """
            const mod = await WebAssembly.compileStreaming(fetch("wasm-runner-data://"));
            // stub WASI imports
            const imports = WebAssembly.Module.imports(mod)
                .filter(x => x.module === "wasi_snapshot_preview1")
                .map(x => [x.name, () => {}]);
            const instance = await WebAssembly.instantiate(mod, {
                wasi_snapshot_preview1: Object.fromEntries(imports)
            });
            api = instance.exports;
            enc = new TextEncoder();
            dec = new TextDecoder();
            api._start();
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
        const inAddr = api.macro_malloc(\(utf8Length));
        const mem = api.memory;
        const arr = new Uint8Array(mem.buffer, inAddr, \(utf8Length));
        enc.encodeInto(json, arr);
        const outAddr = api.macro_parse(inAddr, \(utf8Length));
        const len = new Uint32Array(mem.buffer, outAddr)[0];
        const outArr = new Uint8Array(mem.buffer, outAddr + 4, len);
        const text = dec.decode(outArr);
        api.macro_free(outAddr);
        return text;
        """, arguments: ["json": json], contentWorld: .defaultClient) as! String
    }
}

private final class SchemeHandler<Chunks: AsyncSequence>: NSObject, WKURLSchemeHandler where Chunks.Element == Data {
    typealias RequestHandler<Output> = (URLRequest) async throws -> (Output, URLResponse)

    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private let onRequest: RequestHandler<Chunks>

    init(onRequest: @escaping RequestHandler<Chunks>) {
        self.onRequest = onRequest
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
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

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }
}
