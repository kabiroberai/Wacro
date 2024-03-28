# Wacro

Wacro (**W**ebAssembly M**acro**s) is a proof-of-concept implementation of the _Building Swift Macros with WebAssembly_ proposal [pitched](https://www.swift.org/gsoc2024/) for GSoC 2024.

As of today, Wacro already allows library authors to build macros in WebAssembly and users to consume them like any other Swift library: see the `Example/` folder for details. However there are currently some performance pitfalls — which can be fixed, albeit requiring implementation within the compiler/SwiftPM itself.

**Wacro is not** a GSoC submission: it merely exists to show that this is possible (without even modifying the compiler or SwiftPM!) since the GSoC proposal hasn't seen much movement. A real-world implementation should probably be integrated into the compiler and SwiftPM to improve usability and performance.

## Why?

🐇 Swift Macros as they currently stand are [notoriously slow](https://forums.swift.org/t/compilation-extremely-slow-since-macros-adoption/67921) to compile. This is because most macros depend on `swift-syntax` (Swift's syntax parsing library) in source form, which in turn is a really large library that takes a long time to build.
- swift-syntax is not API/ABI stable, which means this problem can't be solved by pre-compiling it for build host machines.
- Swift itself is not ABI stable on any platform except Darwin. Therefore even if swift-syntax had a stable ABI (seemingly unlikely as this is right now), it would only solve build times on macOS.  
- ✅ By instead shipping macros as WebAssembly binaries, the binaries can be built to statically link a compiled build of swift-syntax. Since WebAssembly is agnostic to the host platform, macro authors can ship one pre-compiled binary that runs on any host machine!

🤝 SwiftPM currently only permits linking to a single version of a package. So if two macros depend on conflicting versions of swift-syntax, SwiftPM will refuse to build.
- ✅ With WebAssembly's "shared-nothing" model, WebAssembly-based macros can link to entirely different versions of swift-syntax and be used by the a client without conflict.

🔐 Swift Macros are intended to be "pure" and not have access to system resources. This is currently realized on macOS via the system sandbox. However, macros are (to my knowledge) not sandboxed on Linux; while this could be somewhat remedied by using [namespaces](https://en.wikipedia.org/wiki/Linux_namespaces), it may require considerable effort and moreover namespaces are widely considered *not* to be a security boundary.
- ✅ Meanwhile, WebAssembly is entirely sandboxed by default, with the possibility to provide access to additional resources using a powerful [capability-based](https://github.com/bytecodealliance/wasmtime/blob/d38d387a1365cc2d809718eca135d138ac754469/docs/WASI-capabilities.md) model.

## How?

Wacro breaks down macros into two phases:

1. **Raw Macro**: The macro source is built into a WASM binary by the macro author, called the **raw** macro. This is just like a regular macro but 1) it is an `.executableTarget` instead of a `.macro` and 2) it depends on `WacroPluginRaw` instead of `SwiftCompilerPlugin`. The binary is checked into source control (ideally one could point to a remote resource instead, but this may require buy-in from SwiftPM.)
2. **Host Macro**: This is the "real" macro consumed by clients. It is a bare-bones `.macro` target where the macro implements `WacroPluginHost`. The only requirement for this conformance is a `providingLibrary: URL` that points to the raw macro's file path.

When the host macro is invoked, `WacroPluginHost` spins up a WebAssembly "runner" which talks to the raw macro to perform the actual work.

## WebAssembly Compilation

With Swift 6.0, support for WASM and WASI has now been [upstreamed](https://forums.swift.org/t/stdlib-and-runtime-tests-for-wasm-wasi-now-available-on-swift-ci/70385). This means that a vanilla Swift 6.0 toolchain can build WASI binaries out of the box given a WASI SDK. 

## WebAssembly Runners

Wacro currently offers two approaches for executing your WebAssembly binary:

1. **WebKit**: This approach relies on `WKWebView`'s WebAssembly support to evaluate macros Just-in-Time.
  - Con: only works on macOS
  - Con: requires `--disable-sandbox` when building hosts since WKWebView uses XPC.
  - Pro: pretty performant (see the Performance section).
  - Pro: requires no additional dependencies, as we use the WebKit library shipped with macOS.
2. **WasmKit**: This approach uses the third-party [WasmKit](https://github.com/swiftwasm/WasmKit) library to interpret WebAssembly macros.
  - Con: the code is interpreted rather than just-in-time compiled, so this approach has a greater constant overhead than using WebKit.
  - Con: adds WasmKit as a dependency to your library, along with its transitive dependencies. These are only used at compile time but add some overhead in the form of fetching and compiling additional modules. This overhead is far less than that of swift-syntax though.
  - Pro: should work on any platform supported by SwiftPM.
  - Pro: does not require disabling the sandbox, or passing any other flags.

WasmKit is currently the default runner, since it is cross-platform and can run sandboxed. Instructions for switching to WebKit are in the following section.

An ideal runner might be a hybrid of these two. On macOS, moving the WebKit runner into the Swift Driver would allow it to be used without disabling the macro sandbox. Meanwhile, WasmKit could be used on other platforms where WebKit is not vended by the system.

## Try it Out

See the [WacroExamples](https://github.com/kabiroberai/WacroExamples) repo. You can either clone it and run `ExampleClient`, or use `ExampleLibrary` as a dependency in any project! Note that there might be some unexpected performance pitfalls right now, but these will be remedied if this makes its way into the Swift compiler. See the following section for details:

## Performance

**Note**: this section is about _build time_ performance. Runtime performance will be identical to a typical macro. The WebAssembly execution process is build-time-only.

### Methodology

- These tests were performed on a 16 inch M3 Max MacBook Pro with 48 GB of unified memory, running macOS 14.1
- Clean builds started with a `make clean`. The wasm binary itself was kept around, since we're looking at performance for clients rather than macro authors.
- WasmKit/WebKit builds were then performed with `time make client [RELEASE=1] [WK=1]`.
- SwiftSyntax builds were performed by modifying `Example/Package.swift` to directly link `ExampleClient` to `ExampleRaw`.

### Results

All values are in seconds.

| Kind                  | WasmKit | WebKit | SwiftSyntax |
|-----------------------|---------|--------|-------------|
| Clean (debug)         | 33.8    | 19.2   | 29.0        |
| Clean (release)       | 32.0    | 18.4   | 183.2       |
| Incremental (debug)   | 9.8     | 1.3    | 0.6         |
| Incremental (release) | 1.1     | 1.5    | 0.8         |

> No, you're not reading that wrong. WasmKit-based macros build _faster_ in release mode because WasmKit itself is compiled with optimizations and can thus interpret wasm macros faster. Ideally, deeper integration with SwiftPM would ensure that WasmKit itself is always built in release mode.
