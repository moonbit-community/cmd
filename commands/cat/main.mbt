///|
let command : @argparse.Command = @argparse.Command(
  "cat",
  flags=[
    @argparse.FlagArg("number", short='n'),
    @argparse.FlagArg("number-nonblank", short='b'),
    @argparse.FlagArg("squeeze-blank", short='s'),
    @argparse.FlagArg("show-tabs", short='T'),
    @argparse.FlagArg("show-ends", short='E'),
    @argparse.FlagArg("show-nonprinting", short='v'),
    @argparse.FlagArg("show-all", short='A'),
    @argparse.FlagArg("show-ends-nonprinting", short='e'),
    @argparse.FlagArg("show-tabs-nonprinting", short='t'),
    @argparse.FlagArg("unbuffered", short='u'),
    @argparse.FlagArg("help", short='h'),
  ],
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
fn help_message() -> String {
  let message =
    #|Usage: cat [OPTION]... [FILE]...
    #|  -h, --help      display this help and exit
    #|      --version   display version and exit
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
    #|  -u, --unbuffered         Accepted no-op (-u is GNU; long spelling is a project alias).
    #|
    #|Project aliases: --show-ends-nonprinting = -e; --show-tabs-nonprinting = -t.
    #|--unbuffered is a project alias of the GNU -u no-op; -h is a project help alias.
    #|
    #|Ordinary option/operand errors exit 1; documented capability refusals retain their own status.
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
  if show_ends && terminated {
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
fn CatRenderer::new(options : @argparse.Matches) -> CatRenderer {
  {
    number: options.flags.contains("number"),
    number_nonblank: options.flags.contains("number-nonblank"),
    squeeze: options.flags.contains("squeeze-blank"),
    show_ends: options.flags.contains("show-ends") ||
    options.flags.contains("show-all") ||
    options.flags.contains("show-ends-nonprinting"),
    show_nonprinting: options.flags.contains("show-nonprinting") ||
    options.flags.contains("show-all") ||
    options.flags.contains("show-ends-nonprinting") ||
    options.flags.contains("show-tabs-nonprinting"),
    show_tabs: options.flags.contains("show-tabs") ||
    options.flags.contains("show-all") ||
    options.flags.contains("show-tabs-nonprinting"),
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
async fn copy_plain(reader : &@io.Reader, buffer : FixedArray[Byte]) -> Unit {
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  while reader.read(buffer, max_len=buffer.length()) is count && count > 0 {
    @stdio.stdout.write(bytes[:count])
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("cat \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = command.parse(argv=args, env=Map([])) catch {
    error => {
      let text = error.to_string()
      let line = match text.rev_find("' found") {
        Some(end) => text[:end + 7]
        None => text.split("\n").next().unwrap_or(text[:])
      }
      let (message, option) = match line {
        [.. "error: unexpected argument '--", .. rest] => {
          let spelling = rest.strip_suffix("' found").unwrap_or(rest)
          let name = spelling.split("=").next().unwrap_or(spelling).to_owned()
          let message = if spelling.contains("=") &&
            [
              "number", "number-nonblank", "squeeze-blank", "show-tabs", "show-ends",
              "show-nonprinting", "show-all", "show-ends-nonprinting", "show-tabs-nonprinting",
              "unbuffered", "help",
            ].contains(name) {
            "flag does not accept a value"
          } else {
            "unknown option"
          }
          (message, name)
        }
        [.. "error: unexpected argument '-", .. rest] =>
          (
            "unknown short option",
            rest.strip_suffix("' found").unwrap_or(rest).to_owned(),
          )
        _ => (text, "")
      }
      @stdio.stderr.write("cat: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.flags.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  let sources = if operands.is_empty() { ["-"][:] } else { operands }
  let formatted = parsed.flags.contains("number") ||
    parsed.flags.contains("number-nonblank") ||
    parsed.flags.contains("squeeze-blank") ||
    parsed.flags.contains("show-tabs") ||
    parsed.flags.contains("show-ends") ||
    parsed.flags.contains("show-nonprinting") ||
    parsed.flags.contains("show-all") ||
    parsed.flags.contains("show-ends-nonprinting") ||
    parsed.flags.contains("show-tabs-nonprinting")
  let mut failed = false
  let renderer = CatRenderer::new(parsed)
  let copy_buffer = FixedArray::make(
    if formatted {
      0
    } else {
      @stream.chunk_size
    },
    b'\x00',
  )
  for path in sources {
    try {
      if path == "-" {
        if formatted {
          renderer.copy(@stdio.stdin)
        } else {
          copy_plain(@stdio.stdin, copy_buffer)
        }
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        if formatted {
          renderer.copy(file)
        } else {
          copy_plain(file, copy_buffer)
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
