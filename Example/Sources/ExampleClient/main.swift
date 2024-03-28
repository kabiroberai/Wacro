import Foundation

@freestanding(expression) macro stringify<T>(_ expression: T) -> (T, String) =
    #externalMacro(module: "ExampleHost", type: "StringifyMacro")

print(#stringify(1 + 1).1)
print(#stringify(2 + 3).1)
