import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import WacroPluginRaw

public enum StringifyMacro: ExpressionMacro {
  public static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) -> ExprSyntax {
    guard let argument = node.arguments.first?.expression else {
      fatalError("compiler bug: the macro does not have any arguments")
    }

    return "(\(argument), \(literal: argument.description))"
  }
}

@main struct ExampleMacros: WacroPluginRaw {
    var providingMacros: [any Macro.Type] {
        [
            StringifyMacro.self
        ]
    }
}
