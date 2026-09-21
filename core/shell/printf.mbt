///|
fn printf_escape(
  chars : Array[Char],
  start : Int,
) -> (String, Int, Bool) raise ShellError {
  if start + 1 >= chars.length() {
    return ("\\", start + 1, false)
  }
  let char = chars[start + 1]
  let value = match char {
    'a' => "\u0007"
    'b' => "\b"
    'f' => "\u000c"
    'n' => "\n"
    'r' => "\r"
    't' => "\t"
    'v' => "\u000b"
    '\\' => "\\"
    'c' => return ("", start + 2, true)
    '0'..='7' => {
      let mut number = 0
      let mut end = start + 1
      let limit = if char == '0' { start + 5 } else { start + 4 }
      while end < chars.length() && end < limit && chars[end] is ('0'..='7') {
        number = number * 8 + chars[end].to_int() - '0'.to_int()
        end += 1
      }
      if number > 127 {
        raise ShellError(
          "printf: non-ASCII octal escapes are not supported by this builtin",
        )
      }
      return (number.unsafe_to_char().to_string(), end, false)
    }
    _ => "\\" + char.to_string()
  }
  (value, start + 2, false)
}

///|
fn printf_string_escapes(value : String) -> (String, Bool) raise ShellError {
  let chars = value.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\\' {
      let (text, next, stop) = printf_escape(chars, index)
      output.write_string(text)
      if stop {
        return (output.to_string(), true)
      }
      index = next
    } else {
      output.write_char(chars[index])
      index += 1
    }
  }
  (output.to_string(), false)
}

///|
fn printf_radix(value : UInt64, radix : UInt64, upper : Bool) -> String {
  if value == 0UL {
    return "0"
  }
  let alphabet = if upper { "0123456789ABCDEF" } else { "0123456789abcdef" }
  let chars : Array[Char] = []
  let mut value = value
  while value > 0UL {
    chars.push(alphabet[(value % radix).to_int()].to_int().unsafe_to_char())
    value = value / radix
  }
  String::from_array(
    Array::makei(chars.length(), i => chars[chars.length() - 1 - i]),
  )
}

///|
async fn printf_builtin(args : Array[String], context : Context) -> Int {
  if args.is_empty() {
    return builtin_error(context, "printf: format required")
  }
  let args = if args[0] == "--" { args[1:].to_owned() } else { args }
  if args.is_empty() {
    return builtin_error(context, "printf: format required")
  }
  let format = args[0].iter().collect()
  let values = args[1:].to_owned()
  let output = StringBuilder()
  let mut argument = 0
  let mut stopped = false
  let mut status = 0
  try {
    for ;; {
      let before = argument
      let mut index = 0
      while index < format.length() && !stopped {
        let char = format[index]
        if char == '\\' {
          let (text, next, stop) = printf_escape(format, index)
          output.write_string(text)
          index = next
          stopped = stop
          continue
        }
        if char != '%' {
          output.write_char(char)
          index += 1
          continue
        }
        index += 1
        if format.get(index) == Some('%') {
          output.write_char('%')
          index += 1
          continue
        }
        let left = format.get(index) == Some('-')
        if left {
          index += 1
        }
        let zero = format.get(index) == Some('0')
        let mut width = 0
        while index < format.length() && format[index] is ('0'..='9') {
          width = width * 10 + format[index].to_int() - '0'.to_int()
          if width > 1000000 {
            raise ShellError("printf: field width exceeds builtin limit")
          }
          index += 1
        }
        guard format.get(index) is Some(conversion) else {
          raise ShellError("printf: incomplete conversion")
        }
        index += 1
        let value = values.get(argument).unwrap_or("")
        if argument < values.length() {
          argument += 1
        }
        let text = match conversion {
          's' => value
          'c' =>
            value.iter().next().map(ch => ch.to_string()).unwrap_or("\u0000")
          'b' => {
            let (text, stop) = printf_string_escapes(value)
            stopped = stop
            text
          }
          'd' | 'i' | 'u' | 'o' | 'x' | 'X' => {
            let number = if value == "" {
              0L
            } else if value.has_prefix("'") || value.has_prefix("\"") {
              value
              .iter()
              .drop(1)
              .next()
              .map(ch => ch.to_int().to_int64())
              .unwrap_or(0L)
            } else {
              arithmetic_number(value) catch {
                _ => {
                  status = 1
                  write_output(
                    context,
                    "sh: printf: '\{value}': numeric argument required\n",
                    error=true,
                  )
                  0L
                }
              }
            }
            match conversion {
              'd' | 'i' => number.to_string()
              'u' => number.reinterpret_as_uint64().to_string()
              'o' => printf_radix(number.reinterpret_as_uint64(), 8UL, false)
              _ =>
                printf_radix(
                  number.reinterpret_as_uint64(),
                  16UL,
                  conversion == 'X',
                )
            }
          }
          _ =>
            raise ShellError("printf: unsupported conversion '%\{conversion}'")
        }
        let padding = String::make(
          if width > text.length() {
            width - text.length()
          } else {
            0
          },
          if zero && !left {
            '0'
          } else {
            ' '
          },
        )
        if left {
          output.write_string(text)
          output.write_string(padding)
        } else if zero && text.has_prefix("-") {
          output.write_char('-')
          output.write_string(padding)
          output.write_string(text[1:].to_owned())
        } else {
          output.write_string(padding)
          output.write_string(text)
        }
      }
      if stopped || argument >= values.length() || argument == before {
        break
      }
    }
  } catch {
    ShellError(message) => {
      write_output(context, output.to_string())
      return builtin_error(context, message)
    }
    err => raise err
  }
  write_output(context, output.to_string())
  status
}
