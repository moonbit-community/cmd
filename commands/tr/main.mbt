///|
priv suberror CliError {
  CliError(String)
}

///|
priv enum SetToken {
  One(Byte)
  Dash
  Class(String, Array[Byte])
  Equiv(Byte)
  Repeat(Byte, Int?)
}

///|
priv struct ExpandedSet {
  bytes : Array[Byte]
  classes : Array[(Int, String)]
  has_equivalence : Bool
  indefinite_repeats : Int
  warnings : Array[String]
}

///|
fn bytes_to_ascii(raw : Bytes, start : Int, end : Int) -> String {
  let out = StringBuilder()
  for index in start..<end {
    out.write_char(raw[index].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
fn is_octal(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'7'
}

///|
fn parse_escaped_byte(
  raw : Bytes,
  start : Int,
  spec : String,
  warnings : Array[String],
) -> (Byte, Int) raise CliError {
  if start + 1 >= raw.length() {
    raise CliError("tr: missing character after backslash in: '\{spec}'")
  }
  let next = raw[start + 1]
  if is_octal(next) {
    let mut value = next.to_int() - b'0'.to_int()
    let mut index = start + 2
    let mut count = 1
    while index < raw.length() && count < 3 && is_octal(raw[index]) {
      let candidate = value * 8 + raw[index].to_int() - b'0'.to_int()
      // GNU consumes only the first two digits when three digits overflow a
      // byte, leaving the third digit as a separate set element.
      if candidate > 0xFF {
        let digits = bytes_to_ascii(raw, start + 1, index + 1)
        let first_two = bytes_to_ascii(raw, start + 1, index)
        let trailing = raw[index].to_int().unsafe_to_char()
        warnings.push(
          "tr: warning: the ambiguous octal escape \\\{digits} is being\n" +
          "\tinterpreted as the 2-byte sequence \\0\{first_two}, \{trailing}\n",
        )
        break
      }
      value = candidate
      index += 1
      count += 1
    }
    return (value.to_byte(), index)
  }
  let escaped = match next {
    b'n' => b'\n'
    b't' => b'\t'
    b'r' => b'\r'
    b'a' => b'\x07'
    b'b' => b'\x08'
    b'f' => b'\x0C'
    b'v' => b'\x0B'
    other => other
  }
  (escaped, start + 2)
}

///|
fn parse_repeat_count(text : String, spec : String) -> Int raise CliError {
  let base = if text.length() > 1 && text[0] == '0' { 8 } else { 10 }
  let mut value = 0
  for char in text {
    let digit = if char is ('0'..='9') {
      char.to_int() - '0'.to_int()
    } else {
      -1
    }
    if digit < 0 || digit >= base || value > (0x0FFF_FFFF - digit) / base {
      raise CliError("tr: invalid repetition count in: '\{spec}'")
    }
    value = value * base + digit
  }
  value
}

///|
fn class_bytes(name : String) -> Array[Byte] raise CliError {
  let out : Array[Byte] = []
  fn push_range(lo : Int, hi : Int) {
    for code in lo..<=hi {
      out.push(code.to_byte())
    }
  }

  match name {
    "lower" => push_range(0x61, 0x7A)
    "upper" => push_range(0x41, 0x5A)
    "digit" => push_range(0x30, 0x39)
    "alpha" => {
      push_range(0x41, 0x5A)
      push_range(0x61, 0x7A)
    }
    "alnum" => {
      push_range(0x30, 0x39)
      push_range(0x41, 0x5A)
      push_range(0x61, 0x7A)
    }
    "space" =>
      for b in [b'\t', b'\n', 0x0B, 0x0C, b'\r', b' '] {
        out.push(b)
      }
    "blank" => {
      out.push(b'\t')
      out.push(b' ')
    }
    "cntrl" => {
      push_range(0, 0x1F)
      out.push(0x7F)
    }
    "graph" => push_range(0x21, 0x7E)
    "print" => push_range(0x20, 0x7E)
    "punct" => {
      push_range(0x21, 0x2F)
      push_range(0x3A, 0x40)
      push_range(0x5B, 0x60)
      push_range(0x7B, 0x7E)
    }
    "xdigit" => {
      push_range(0x30, 0x39)
      push_range(0x41, 0x46)
      push_range(0x61, 0x66)
    }
    _ => raise CliError("tr: unsupported character class: '[:\{name}:]'")
  }
  out
}

///|
fn parse_set_tokens(
  spec : String,
  warnings : Array[String],
) -> Array[SetToken] raise CliError {
  let raw = @utf8.encode(spec)
  let tokens : Array[SetToken] = []
  let mut i = 0
  while i < raw.length() {
    let c = raw[i]
    if c == b'\\' {
      let (escaped, next) = parse_escaped_byte(raw, i, spec, warnings)
      tokens.push(One(escaped))
      i = next
    } else if c == b'[' && i + 3 < raw.length() && raw[i + 1] == b'=' {
      let (equivalent, next) = if raw[i + 2] == b'\\' {
        parse_escaped_byte(raw, i + 2, spec, warnings)
      } else {
        (raw[i + 2], i + 3)
      }
      if next + 1 >= raw.length() || raw[next] != b'=' || raw[next + 1] != b']' {
        raise CliError("tr: invalid equivalence class in: '\{spec}'")
      }
      tokens.push(Equiv(equivalent))
      i = next + 2
    } else if c == b'[' &&
      i + 3 < raw.length() &&
      (raw[i + 1] == b'\\' || raw[i + 2] == b'*') {
      let (repeated, after_char) = if raw[i + 1] == b'\\' {
        parse_escaped_byte(raw, i + 1, spec, warnings)
      } else {
        (raw[i + 1], i + 2)
      }
      if after_char < raw.length() && raw[after_char] == b'*' {
        let mut j = after_char + 1
        while j < raw.length() && raw[j] != b']' {
          if raw[j] < b'0' || raw[j] > b'9' {
            raise CliError("tr: invalid repetition count in: '\{spec}'")
          }
          j += 1
        }
        if j >= raw.length() {
          raise CliError("tr: unterminated repetition in: '\{spec}'")
        }
        let count = if j == after_char + 1 {
          None
        } else {
          let text = bytes_to_ascii(raw, after_char + 1, j)
          let value = parse_repeat_count(text, spec)
          if value == 0 {
            None
          } else {
            Some(value)
          }
        }
        tokens.push(Repeat(repeated, count))
        i = j + 1
      } else {
        tokens.push(One(c))
        i += 1
      }
    } else if c == b'[' && i + 1 < raw.length() && raw[i + 1] == b':' {
      let mut j = i + 2
      while j + 1 < raw.length() && !(raw[j] == b':' && raw[j + 1] == b']') {
        if raw[j] < 0x20 || raw[j] > 0x7E {
          raise CliError("tr: invalid repetition count in: '\{spec}'")
        }
        j += 1
      }
      if j + 1 >= raw.length() {
        raise CliError("tr: unterminated character class in: '\{spec}'")
      }
      let name = bytes_to_ascii(raw, i + 2, j)
      tokens.push(Class(name, class_bytes(name)))
      i = j + 2
    } else if c == b'-' {
      tokens.push(Dash)
      i += 1
    } else {
      tokens.push(One(c))
      i += 1
    }
  }
  tokens
}

///|
fn expand_set_details(
  spec : String,
  fill_length : Int?,
) -> ExpandedSet raise CliError {
  let warnings : Array[String] = []
  let tokens = parse_set_tokens(spec, warnings)
  let mut fixed_length = 0
  let mut indefinite_repeats = 0
  let mut token_index = 0
  while token_index < tokens.length() {
    match tokens[token_index] {
      One(_) | Equiv(_) => {
        fixed_length += 1
        token_index += 1
      }
      Dash =>
        if token_index > 0 &&
          token_index + 1 < tokens.length() &&
          tokens[token_index - 1] is One(lo) &&
          tokens[token_index + 1] is One(hi) &&
          lo <= hi {
          fixed_length += hi.to_int() - lo.to_int()
          token_index += 2
        } else {
          fixed_length += 1
          token_index += 1
        }
      Class(_, bytes) => {
        fixed_length += bytes.length()
        token_index += 1
      }
      Repeat(_, Some(count)) => {
        fixed_length += count
        token_index += 1
      }
      Repeat(_, None) => {
        indefinite_repeats += 1
        token_index += 1
      }
    }
  }
  if indefinite_repeats > 1 {
    raise CliError("tr: only one [c*] repeat construct may appear in SET2")
  }
  let bytes : Array[Byte] = []
  let classes : Array[(Int, String)] = []
  let mut has_equivalence = false
  let mut k = 0
  while k < tokens.length() {
    match tokens[k] {
      Dash =>
        if k > 0 &&
          k + 1 < tokens.length() &&
          tokens[k - 1] is One(lo) &&
          tokens[k + 1] is One(hi) {
          if lo.to_int() > hi.to_int() {
            raise CliError("tr: range endpoints out of order in: '\{spec}'")
          }
          // The lower endpoint was already pushed when One(lo) was visited.
          for code in (lo.to_int() + 1)..<=hi.to_int() {
            bytes.push(code.to_byte())
          }
          k += 2
        } else {
          bytes.push(b'-')
          k += 1
        }
      One(b) => {
        bytes.push(b)
        k += 1
      }
      Equiv(b) => {
        bytes.push(b)
        has_equivalence = true
        k += 1
      }
      Class(name, class) => {
        classes.push((bytes.length(), name))
        bytes.append(class)
        k += 1
      }
      Repeat(byte, count) => {
        let repetitions = match count {
          Some(value) => value
          None => {
            guard fill_length is Some(target) else {
              raise CliError("tr: [c*] repetition is only valid in SET2")
            }
            if target > fixed_length {
              target - fixed_length
            } else {
              0
            }
          }
        }
        for _ in 0..<repetitions {
          bytes.push(byte)
        }
        k += 1
      }
    }
  }
  { bytes, classes, has_equivalence, indefinite_repeats, warnings, }
}

///|
fn validate_translation_sets(
  set1 : ExpandedSet,
  set2 : ExpandedSet,
  complement : Bool,
) -> Unit raise CliError {
  if set2.has_equivalence {
    raise CliError(
      "tr: equivalence classes may not appear in SET2 when translating",
    )
  }
  for entry in set2.classes {
    let (position, name) = entry
    if name != "lower" && name != "upper" {
      raise CliError(
        "tr: only lower and upper character classes may appear in SET2 when translating",
      )
    }
    let mut aligned = false
    for source_entry in set1.classes {
      let (source_position, source_name) = source_entry
      if source_position == position &&
        (source_name == "lower" || source_name == "upper") {
        aligned = true
      }
    }
    if !aligned {
      raise CliError("tr: misaligned lower/upper character class in SET2")
    }
  }
  if complement && !set1.classes.is_empty() && set2.bytes.length() > 1 {
    let first = set2.bytes[0]
    for byte in set2.bytes[1:] {
      if byte != first {
        raise CliError(
          "tr: complemented character classes require one repeated SET2 byte",
        )
      }
    }
  }
}

///|
fn membership(set : Array[Byte]) -> FixedArray[Bool] {
  let table = FixedArray::make(256, false)
  for b in set {
    table[b.to_int()] = true
  }
  table
}

///|
fn complement_set(set : Array[Byte]) -> Array[Byte] {
  let table = membership(set)
  let out : Array[Byte] = []
  for code in 0..<=255 {
    if !table[code] {
      out.push(code.to_byte())
    }
  }
  out
}

///|
async fn transform_stream(
  delete : FixedArray[Bool]?,
  translate : FixedArray[Byte]?,
  squeeze : FixedArray[Bool]?,
) -> Unit {
  let mut previous = -1
  while @stream.read_chunk(@stdio.stdin) is Some(chunk) {
    let out : Array[Byte] = []
    for input in chunk {
      let input_code = input.to_int()
      if delete is Some(table) && table[input_code] {
        continue
      }
      let byte = match translate {
        Some(table) => table[input_code]
        None => input
      }
      let code = byte.to_int()
      if squeeze is Some(table) && code == previous && table[code] {
        continue
      }
      out.push(byte)
      previous = code
    }
    if !out.is_empty() {
      @stdio.stdout.write(Bytes::from_array(out))
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("delete", short='d'),
    @cli.flag("squeeze-repeats", short='s'),
    @cli.flag("complement", short='c'),
    @cli.flag("complement", short='C'),
    @cli.flag("truncate-set1", short='t'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tr: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: tr [-dscCt] SET1 [SET2]\n")
    return
  }
  let delete = parsed.contains("delete")
  let squeeze_repeats = parsed.contains("squeeze-repeats")
  let complement = parsed.contains("complement")
  let truncate_set1 = parsed.contains("truncate-set1")
  let sets = parsed.operands
  if sets.is_empty() {
    @stdio.stderr.write("tr: missing operand\n")
    @sys.exit(2)
    return
  }
  if sets.length() > 2 {
    @stdio.stderr.write("tr: extra operand '\{sets[2]}'\n")
    @sys.exit(2)
    return
  }
  try {
    let set1_details = expand_set_details(sets[0], None)
    let set1_bytes = if complement {
      complement_set(set1_details.bytes)
    } else {
      set1_details.bytes
    }
    let set2_details = if sets.length() > 1 {
      Some(expand_set_details(sets[1], Some(set1_bytes.length())))
    } else {
      None
    }
    if @env.get_env_var("POSIXLY_CORRECT") is None {
      for warning in set1_details.warnings {
        @stdio.stderr.write(warning)
      }
      for details in set2_details {
        for warning in details.warnings {
          @stdio.stderr.write(warning)
        }
      }
    }
    let set2_bytes = match set2_details {
      Some(details) => details.bytes
      None => []
    }
    if !delete && sets.length() == 1 && !squeeze_repeats {
      raise CliError("tr: two sets must be given when translating")
    }
    if delete && sets.length() > 1 && !squeeze_repeats {
      raise CliError(
        "tr: extra operand '\{sets[1]}' (a second set is only used with -s)",
      )
    }
    if delete && squeeze_repeats && sets.length() == 1 {
      raise CliError(
        "tr: two sets must be given when both deleting and squeezing repeats",
      )
    }
    if !delete && sets.length() > 1 && set2_details is Some(details) {
      validate_translation_sets(set1_details, details, complement)
    } else if set2_details is Some(details) && details.indefinite_repeats > 0 {
      raise CliError(
        "tr: [c*] repetition in SET2 is valid only when translating",
      )
    }
    if delete {
      transform_stream(
        Some(membership(set1_bytes)),
        None,
        if squeeze_repeats && sets.length() > 1 {
          Some(membership(set2_bytes))
        } else {
          None
        },
      )
    } else if sets.length() > 1 {
      if set2_bytes.is_empty() {
        raise CliError("tr: SET2 must be non-empty when translating")
      }
      let map = FixedArray::make(256, b'\x00')
      for code in 0..<=255 {
        map[code] = code.to_byte()
      }
      let translate_count = if truncate_set1 &&
        set2_bytes.length() < set1_bytes.length() {
        set2_bytes.length()
      } else {
        set1_bytes.length()
      }
      for index in 0..<translate_count {
        let from = set1_bytes[index]
        let to = if index < set2_bytes.length() {
          set2_bytes[index]
        } else {
          set2_bytes[set2_bytes.length() - 1]
        }
        map[from.to_int()] = to
      }
      transform_stream(
        None,
        Some(map),
        if squeeze_repeats {
          Some(membership(set2_bytes))
        } else {
          None
        },
      )
    } else {
      // -s with a single set.
      transform_stream(None, None, Some(membership(set1_bytes)))
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
    err => {
      @stdio.stderr.write("tr: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
