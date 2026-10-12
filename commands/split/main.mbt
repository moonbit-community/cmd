///|
fn positive(value : String) -> Int raise {
  let result = @string.parse_int(value)
  guard result > 0 else { fail("invalid positive count: \{value}") }
  result
}

///|
fn byte_count(value : String) -> Int raise {
  let mut end = 0
  while end < value.length() && value[end] >= '0' && value[end] <= '9' {
    end += 1
  }
  guard end > 0 else { fail("invalid byte count: \{value}") }
  let count = positive(value[:end].to_owned())
  let suffix = value[end:].to_owned()
  let multiplier = match suffix {
    "" => 1
    "b" => 512
    "kB" => 1000
    "K" | "KiB" => 1024
    "MB" => 1000000
    "M" | "MiB" => 1048576
    "GB" => 1000000000
    "G" | "GiB" => 1073741824
    _ => fail("unsupported byte multiplier: \{suffix}")
  }
  guard count <= 2147483647 / multiplier else {
    fail("byte count is too large")
  }
  count * multiplier
}

///|
fn boundaries(data : Bytes, size : Int, lines : Bool) -> Array[(Int, Int)] {
  let result : Array[(Int, Int)] = []
  let mut start = 0
  let mut count = 0
  for index in 0..<data.length() {
    if !lines || data[index] == b'\n' {
      count += 1
    }
    if count == size {
      result.push((start, index + 1))
      start = index + 1
      count = 0
    }
  }
  if start < data.length() {
    result.push((start, data.length()))
  }
  result
}

///|
fn advance_suffix(digits : Array[Int], radix : Int, automatic : Bool) -> Bool {
  let mut position = digits.length() - 1
  while position >= 0 {
    digits[position] += 1
    if digits[position] < radix {
      break
    }
    digits[position] = 0
    position -= 1
  }
  if position < 0 {
    return false
  }
  if automatic {
    let prefix_length = (digits.length() - 2) / 2
    if digits[prefix_length] == radix - 1 {
      digits.clear()
      for _ in 0..<(prefix_length + 1) {
        digits.push(radix - 1)
      }
      for _ in 0..<(prefix_length + 3) {
        digits.push(0)
      }
    }
  }
  true
}

///|
fn suffix_name(digits : Array[Int], numeric : Bool) -> String {
  let output = StringBuilder()
  let base = if numeric { 48 } else { 97 }
  for digit in digits {
    output.write_char((base + digit).unsafe_to_char())
  }
  output.to_string()
}

///|
fn help_message() -> String {
  let message =
    #|Usage: split [OPTION]... [FILE [PREFIX]]
    #|Split FILE (or stdin) into pieces named PREFIXaa, PREFIXab, ...
    #|The default PREFIX is x; the default piece size is 1000 lines.
    #|
    #|  -l, --lines=NUMBER        Put NUMBER lines in each output.
    #|  -b, --bytes=SIZE          Put SIZE bytes in each output (K, M, G, kB, MB, GB).
    #|  -a, --suffix-length=N     Use fixed-width suffixes of N characters.
    #|  -d, --numeric-suffixes    Use numeric suffixes starting at zero.
    #|      --additional-suffix=SUFFIX  Append SUFFIX after generated suffixes.
    #|      --help               display this help and exit
    #|      --version            display version and exit
    #|
    #|Existing output paths are refused. Chunk distribution, filters, and
    #|line-byte mode are unsupported.
  message
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("split 0.1.0\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.option("lines", short='l'),
    @cli.option("bytes", short='b'),
    @cli.option("suffix-length", short='a'),
    @cli.flag("numeric-suffixes", short='d'),
    @cli.option("additional-suffix"),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(message~, option~, ..) => {
      @stdio.stderr.write("split: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("split 0.1.0\n")
    return
  }
  let (size, lines, width, additional) = try {
    guard parsed.operands.length() <= 2 else { fail("too many operands") }
    guard !(parsed.contains("bytes") && parsed.contains("lines")) else {
      fail("cannot split in more than one way")
    }
    let lines = !parsed.contains("bytes")
    let size = if lines {
      positive(parsed.last_value("lines").unwrap_or("1000"))
    } else {
      byte_count(parsed.last_value("bytes").unwrap())
    }
    let width = positive(parsed.last_value("suffix-length").unwrap_or("2"))
    guard width <= 1024 else {
      fail("suffix length exceeds this build's limit of 1024")
    }
    let additional = parsed.last_value("additional-suffix").unwrap_or("")
    guard !additional.contains("/") && !additional.contains("\\") else {
      fail("additional suffix must not contain a path separator")
    }
    (size, lines, width, additional)
  } catch {
    err => {
      @stdio.stderr.write("split: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  let input = parsed.operands.get(0).unwrap_or("-")
  let prefix = parsed.operands.get(1).unwrap_or("x")
  let numeric = parsed.contains("numeric-suffixes")
  try {
    let data = if input == "-" {
      @stdio.stdin.read_all().binary()
    } else {
      @fs.read_file(input).binary()
    }
    let chunks = boundaries(data, size, lines)
    let digits = Array::make(width, 0)
    for index, (start, end) in chunks {
      if index > 0 &&
        !advance_suffix(
          digits,
          if numeric {
            10
          } else {
            26
          },
          !parsed.contains("suffix-length"),
        ) {
        fail("output file suffixes exhausted")
      }
      let output = prefix + suffix_name(digits, numeric) + additional
      if @fs.exists(output) {
        fail("existing output is unsupported: \{output}")
      }
      @fs.write_file(output, data[start:end], create_mode=CreateNew)
    }
  } catch {
    err => {
      @stdio.stderr.write("split: \{err}\n")
      @sys.exit(1)
    }
  }
}
