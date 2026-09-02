///|
fn help_message() -> String {
  let message =
    #|Usage: cat [OPTION]... [FILE]...
    #|
    #|Concatenate FILEs (or stdin) to standard output, byte-transparently:
    #|no decoding, no newline normalization. Use '-' or no file for stdin.
    #|
    #|  -n, --number             Number all output lines.
    #|  -b, --number-nonblank    Number nonempty output lines (overrides -n).
    #|  -s, --squeeze-blank      Suppress repeated empty output lines.
    #|  -T, --show-tabs          Display TAB as ^I.
    #|  -E, --show-ends          Display '$' at the end of each line.
    #|  -v, --show-nonprinting   Display nonprinting bytes visibly.
    #|  -A, --show-all           Equivalent to -vET.
    #|  -e                       Equivalent to -vE.
    #|  -t                       Equivalent to -vT.
    #|  -h, --help               Show this help message.
  message
}

///|
fn append_char(output : Array[Byte], char : Char) -> Unit {
  output.push(char.to_int().to_byte())
}

///|
fn append_text(output : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text) {
    output.push(byte)
  }
}

///|
fn append_number(output : Array[Byte], number : Int64) -> Unit {
  let text = number.to_string()
  let padding = 6 - text.length()
  for _ in 0..<padding.max(0) {
    append_char(output, ' ')
  }
  append_text(output, text)
  append_char(output, '\t')
}

///|
fn append_visible_byte(
  output : Array[Byte],
  byte : Byte,
  show_tabs : Bool,
) -> Unit {
  let value = byte.to_int()
  if value == 0x09 && !show_tabs {
    output.push(byte)
  } else if value == 0x09 {
    append_text(output, "^I")
  } else if value < 0x20 {
    append_char(output, '^')
    append_char(output, (value + 0x40).unsafe_to_char())
  } else if value == 0x7f {
    append_text(output, "^?")
  } else if value >= 0x80 {
    append_text(output, "M-")
    append_visible_byte(output, (value - 0x80).to_byte(), show_tabs)
  } else {
    output.push(byte)
  }
}

///|
fn render_line(
  line : Array[Byte],
  output : Array[Byte],
  number : Int64,
  number_lines : Bool,
  number_nonblank : Bool,
  show_ends : Bool,
  show_nonprinting : Bool,
  show_tabs : Bool,
  terminated : Bool,
) -> Unit {
  let nonblank = line.length() > 0
  if number_lines && (!number_nonblank || nonblank) {
    append_number(output, number)
  }
  for byte in line {
    if show_nonprinting {
      append_visible_byte(output, byte, show_tabs)
    } else if show_tabs && byte == b'\t' {
      append_text(output, "^I")
    } else {
      output.push(byte)
    }
  }
  if show_ends {
    append_char(output, '$')
  }
  if terminated {
    append_char(output, '\n')
  }
}

///|
priv struct CatRenderer {
  number : Bool
  number_nonblank : Bool
  squeeze : Bool
  show_ends : Bool
  show_nonprinting : Bool
  show_tabs : Bool
  line : Array[Byte]
  mut line_number : Int64
  mut previous_blank : Bool
}

///|
fn CatRenderer::new(options : @cli.ParsedArgs) -> CatRenderer {
  {
    number: options.contains("number"),
    number_nonblank: options.contains("number-nonblank"),
    squeeze: options.contains("squeeze-blank"),
    show_ends: options.contains("show-ends") ||
    options.contains("show-all") ||
    options.contains("show-ends-nonprinting"),
    show_nonprinting: options.contains("show-nonprinting") ||
    options.contains("show-all") ||
    options.contains("show-ends-nonprinting") ||
    options.contains("show-tabs-nonprinting"),
    show_tabs: options.contains("show-tabs") ||
    options.contains("show-all") ||
    options.contains("show-tabs-nonprinting"),
    line: [],
    line_number: 1,
    previous_blank: false,
  }
}

///|
fn CatRenderer::flush(self : CatRenderer, terminated : Bool) -> Bytes {
  let blank = self.line.is_empty()
  if terminated && self.squeeze && blank && self.previous_blank {
    return b""
  }
  let output : Array[Byte] = []
  render_line(
    self.line,
    output,
    self.line_number,
    self.number || self.number_nonblank,
    self.number_nonblank,
    self.show_ends,
    self.show_nonprinting,
    self.show_tabs,
    terminated,
  )
  if (self.number || self.number_nonblank) && (!self.number_nonblank || !blank) {
    self.line_number += 1
  }
  self.line.clear()
  if terminated {
    self.previous_blank = blank
  }
  Bytes::from_array(output)
}

///|
async fn CatRenderer::copy(self : CatRenderer, reader : &@io.Reader) -> Unit {
  while @stream.read_chunk(reader) is Some(chunk) {
    let output : Array[Byte] = []
    for byte in chunk {
      if byte == b'\n' {
        for rendered in self.flush(true) {
          output.push(rendered)
        }
      } else {
        self.line.push(byte)
      }
    }
    if !output.is_empty() {
      @stdio.stdout.write(Bytes::from_array(output))
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("number", short='n'),
    @cli.flag("number-nonblank", short='b'),
    @cli.flag("squeeze-blank", short='s'),
    @cli.flag("show-tabs", short='T'),
    @cli.flag("show-ends", short='E'),
    @cli.flag("show-nonprinting", short='v'),
    @cli.flag("show-all", short='A'),
    @cli.flag("show-ends-nonprinting", short='e'),
    @cli.flag("show-tabs-nonprinting", short='t'),
    @cli.flag("help", short='h'),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cat: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let operands = parsed.operands
  let sources = if operands.is_empty() { ["-"][:] } else { operands }
  let formatted = parsed.contains("number") ||
    parsed.contains("number-nonblank") ||
    parsed.contains("squeeze-blank") ||
    parsed.contains("show-tabs") ||
    parsed.contains("show-ends") ||
    parsed.contains("show-nonprinting") ||
    parsed.contains("show-all") ||
    parsed.contains("show-ends-nonprinting") ||
    parsed.contains("show-tabs-nonprinting")
  let mut failed = false
  let renderer = CatRenderer::new(parsed)
  for path in sources {
    try {
      if path == "-" {
        if formatted {
          renderer.copy(@stdio.stdin)
        } else {
          @stdio.stdout.write_reader(@stdio.stdin)
        }
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        if formatted {
          renderer.copy(file)
        } else {
          @stdio.stdout.write_reader(file)
        }
      }
    } catch {
      err => {
        @stdio.stderr.write("cat: \{err}\n")
        failed = true
      }
    }
  }
  if formatted && !renderer.line.is_empty() {
    @stdio.stdout.write(renderer.flush(false))
  }
  if failed {
    @sys.exit(1)
  }
}
