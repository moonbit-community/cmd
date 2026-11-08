///|
fn make_shell_fast_arguments(script : String, ifs : String) -> Array[String]? {
  for char in ifs {
    if !(char is (' ' | '\t' | '\n')) {
      return None
    }
  }
  let chars = script.iter().collect()
  let arguments : Array[String] = []
  let word = StringBuilder()
  let mut present = false
  let mut quoted = false
  let mut index = 0
  while index < chars.length() {
    let char = chars[index]
    if quoted {
      if char == '\'' {
        quoted = false
      } else {
        word.write_char(char)
      }
    } else if char == '\\' {
      index += 1
      if index < chars.length() {
        if chars[index] == '\n' {
          if word.is_empty() {
            while index + 1 < chars.length() && chars[index + 1] is (' ' | '\t') {
              index += 1
            }
          }
        } else {
          present = true
          word.write_char(chars[index])
        }
      }
    } else if char == '\'' {
      quoted = true
      present = true
    } else if char is (' ' | '\t') {
      if present {
        arguments.push(word.to_string())
        word.reset()
        present = false
      }
    } else {
      if "#;\"*?[]&|<>(){}$`^~!".contains(char.to_string()) ||
        (arguments.is_empty() && char == '=') {
        return None
      }
      present = true
      word.write_char(char)
    }
    index += 1
  }
  if quoted {
    return None
  }
  if present {
    arguments.push(word.to_string())
  }
  if arguments.get(0) is Some(command) &&
    [
      ".", ":", "alias", "bg", "break", "case", "cd", "command", "continue", "eval",
      "exec", "exit", "export", "fc", "fg", "for", "getopts", "hash", "if", "jobs",
      "login", "logout", "read", "readonly", "return", "set", "shift", "test", "times",
      "trap", "type", "ulimit", "umask", "unalias", "unset", "wait", "while",
    ].contains(command) {
    return None
  }
  Some(arguments)
}

///|
fn make_shell_source(
  script : String,
  ifs : String,
  force_shell~ : Bool = false,
) -> String? {
  let mut start = 0
  while start < script.length() && script[start] is (' ' | '\t') {
    start += 1
  }
  let script = script[start:].to_owned()
  if script == "" {
    return None
  }
  // GNU's default /bin/sh argv builder treats LF as an ordinary byte on its
  // direct-argv path. Quoting those arguments preserves them in our interpreter.
  if !force_shell && make_shell_fast_arguments(script, ifs) is Some(arguments) {
    if arguments.is_empty() {
      return None
    }
    return Some(
      arguments
      .map(argument => "'" + argument.replace_all(old="'", new="'\\''") + "'")
      .join(" "),
    )
  }
  // The shell path escapes the source then reparses its argv. This removes a
  // raw LF but preserves an original backslash-LF pair for the shell itself.
  let chars = script.iter().collect()
  let result = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\\' && chars.get(index + 1) == Some('\n') {
      result.write_string("\\\n")
      index += 2
    } else {
      if chars[index] != '\n' {
        result.write_char(chars[index])
      }
      index += 1
    }
  }
  Some(result.to_string())
}
