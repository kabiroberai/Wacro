all:: wasm client

wasm::
	swift build --experimental-swift-sdk wasm32-unknown-wasi --product ExampleRaw -c release -Xswiftc -Osize
	# rename to dylib to sneak past the sandbox
	# https://github.com/apple/swift/blob/418dd95d8e324666e6ad4ecc13de7344ccc12fed/lib/Basic/Sandbox.cpp#L28
	cp -a .build/wasm32-unknown-wasi/release/ExampleRaw.wasm ExampleRaw.wasm.dylib

# WebMacroRunner uses WKWebView which can't run in the macro sandbox
client::
	$(if $(WK),WEBKIT_RUNNER=1) swift build --product ExampleClient $(if $(WK),--disable-sandbox) $(SWIFTFLAGS) $(if $(RELEASE),-c release)

run:: client
	.build/debug/ExampleClient

clean::
	rm -rf .build

distclean:: clean
	rm -rf ExampleRaw.wasm.dylib
