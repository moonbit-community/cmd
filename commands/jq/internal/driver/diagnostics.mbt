///|
fn compile_diagnostic(
  message : String,
  symbol : String,
  position : Int32,
  source : String,
  text : String,
) -> String {
  let mut line = 1
  let mut start = 0
  for index in 0..<position.min(text.length()) {
    if text[index] == '\n' {
      line += 1
      start = index + 1
    }
  }
  let rest = text[start:]
  let end = rest.find("\n").unwrap_or(rest.length())
  let column = position - start + 1
  "jq: error: \{message} at \{source}, line \{line}, column \{column}:\n    " +
  rest[:end].to_owned() +
  "\n    " +
  String::make(column - 1, ' ') +
  String::make(symbol.length().max(1), '^') +
  "\njq: 1 compile error\n"
}
