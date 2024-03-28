all:: wasm client

wasm::
	swift build --package-path Example --experimental-swift-sdk wasm32-unknown-wasi --product ExampleRaw -c release -Xswiftc -Osize
	cp -a Example/.build/wasm32-unknown-wasi/release/ExampleRaw.wasm Example/Sources/ExampleHostContainer/

client::
	swift build --package-path Example --product ExampleClient --disable-sandbox

run:: client
	Example/.build/debug/ExampleClient

clean::
	rm -rf Example/.build Example/Sources/ExampleHostContainer/ExampleRaw.wasm
