all:: wasm client

wasm::
	swift build --package-path Example --experimental-swift-sdk wasm32-unknown-wasi --product ExampleRaw -c release -Xswiftc -Osize
	# rename to dylib to sneak past the sandbox
	# https://github.com/apple/swift/blob/418dd95d8e324666e6ad4ecc13de7344ccc12fed/lib/Basic/Sandbox.cpp#L28
	cp -a Example/.build/wasm32-unknown-wasi/release/ExampleRaw.wasm Example/ExampleRaw.wasm.dylib

client::
	swift build --package-path Example --product ExampleClient

run:: client
	Example/.build/debug/ExampleClient

clean::
	rm -rf Example/.build Example/ExampleRaw.wasm.dylib
