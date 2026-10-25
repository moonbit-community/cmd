///|
fn builtin_mode(name : String) -> Bool {
  [
    "one-byte-octal", "one-byte-char", "canonical", "two-bytes-decimal", "two-bytes-octal",
    "two-bytes-hex", "one-byte-hex",
  ].contains(name)
}

///|
fn finish_program(
  entries : Array[FormatEntry],
) -> FormatProgram raise HexdumpError {
  let mut block_size = 0
  let mut final_unit : FormatUnit? = None
  for entry in entries {
    match entry {
      Builtin(mode) => {
        if block_size < 16 {
          block_size = 16
        }
        let format = compile_format(
          @utf8.encode(
            if mode == "canonical" {
              "\"%08.8_Ax\\n\""
            } else {
              "\"%07.7_Ax\\n\""
            },
          )[:],
          false,
        )
        final_unit = format.units.get(0)
      }
      Custom(format) => {
        if block_size < format.count {
          block_size = format.count
        }
        for unit in format.units {
          if unit.final_address {
            final_unit = Some(unit)
          }
        }
      }
    }
  }
  for entry in entries {
    if entry is Custom(format) &&
      format.count < block_size &&
      format.units.last() is Some(unit) &&
      !unit.explicit_reps &&
      unit.count > 0 {
      unit.reps += (block_size - format.count) / unit.count
    }
  }
  { entries, block_size, final_unit, }
}

///|
fn normalized_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      result.push(arg)
      value_next = false
      continue
    }
    if arg == "--" {
      options = false
      result.push(arg)
      continue
    }
    if !options {
      result.push(arg)
      continue
    }
    if arg == "--color" {
      result.push("--color=auto")
      continue
    }
    let mut rewritten = false
    if arg.has_prefix("-") && !arg.has_prefix("--") {
      for index in 1..<arg.length() {
        if arg[index] is ('e' | 'f' | 'n' | 's') {
          value_next = index + 1 == arg.length()
          break
        }
        if arg[index] == 'L' {
          if index > 1 {
            result.push(arg[:index].to_owned())
          }
          let value = if index + 1 == arg.length() {
            "auto"
          } else {
            arg[index + 1:].to_owned()
          }
          result.push("--color=" + value)
          rewritten = true
          break
        }
      }
    }
    if !rewritten {
      result.push(arg)
    }
    if ["--format", "--format-file", "--length", "--skip"].contains(arg) {
      value_next = true
    }
  }
  result
}

///|
async fn program(parsed : @cli.ParsedArgs) -> FormatProgram {
  let entries : Array[FormatEntry] = []
  let mut colors = false
  for value in parsed.values("color") {
    match value {
      "always" => colors = true
      "auto" | "never" => colors = false
      _ => raise HexdumpError("unsupported color mode: '\{value}'")
    }
  }
  let mut format_index = 0
  let mut file_index = 0
  for name in parsed.order {
    if builtin_mode(name) {
      entries.push(Builtin(name))
    } else if name == "format" {
      let source = parsed.values("format")[format_index]
      entries.push(Custom(compile_format(@utf8.encode(source)[:], colors)))
      format_index += 1
    } else if name == "format-file" {
      let file = parsed.values("format-file")[file_index]
      let bytes = @fs.read_file(file).binary()
      let mut start = 0
      for index in 0..<=bytes.length() {
        if index == bytes.length() || bytes[index] == b'\n' {
          let mut first = start
          while first < index && format_space(bytes[first]) {
            first += 1
          }
          if first < index && bytes[first] != b'#' {
            entries.push(Custom(compile_format(bytes[first:index], colors)))
          }
          start = index + 1
        }
      }
      file_index += 1
    }
  }
  if entries.is_empty() {
    entries.push(Builtin("default"))
  }
  finish_program(entries)
}
