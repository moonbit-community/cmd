///|
priv struct ManifestRecord {
  spec : DigestSpec
  expected : Bytes
  name : String
}

///|
priv struct ManifestFormat {
  mut reversed : Int32
  mut label : String
  mut sha2_tag : Digest?
}

///|
fn blank(char : UInt16) -> Bool {
  char is (' ' | '\t')
}

///|
fn parse_bits(value : String) -> Int32? {
  if value.is_empty() || !value.iter().all(c => c is ('0'..<='9')) {
    return None
  }
  Some(@string.parse_int(value)) catch {
    _ => None
  }
}

///|
fn valid_width(algorithm : Digest, bits : Int32) -> Bool {
  match algorithm {
    Sha2 | Sha3 => bits is (224 | 256 | 384 | 512)
    _ => bits > 0 && bits % 8 == 0 && bits <= algorithm.default_bits()
  }
}

///|
fn tagged_spec(tag : String, selected : Digest?, modern : Bool) -> DigestSpec? {
  let mut base = tag
  let mut width : Int32? = None
  if tag.find("-") is Some(index) {
    if !modern {
      return None
    }
    base = tag[:index].to_owned()
    width = parse_bits(tag[index + 1:].to_owned())
    if width is None {
      return None
    }
  }
  let algorithm = match base {
    "MD5" => Fixed(Md5)
    "SHA1" => Fixed(Sha1)
    "SHA224" => Sha224
    "SHA256" => Fixed(Sha256)
    "SHA384" => Sha384
    "SHA512" => Fixed(Sha512)
    "SHA2" => Sha2
    "SHA3" => Sha3
    "BLAKE2b" => Blake2b
    "SM3" => Sm3
    _ => return None
  }
  if selected is Some(choice) {
    let compatible = if choice is Sha2 {
      algorithm is (Sha2 | Sha224 | Sha384 | Fixed(Sha256 | Sha512))
    } else {
      algorithm.label() == choice.label()
    }
    if !compatible {
      return None
    }
  }
  let bits = width.unwrap_or(algorithm.default_bits())
  if !valid_width(algorithm, bits) {
    return None
  }
  Some({ algorithm, bits, })
}

///|
fn decode_digest(value : String, bits : Int32, modern : Bool) -> Bytes? {
  if value.length() == bits / 4 &&
    value.iter().all(c => c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F')) {
    return Some(@hex.decode(value[:])) catch { _ => None }
  }
  if modern && value.length() == (bits / 8 + 2) / 3 * 4 {
    let decoded = @base64.decode(value[:]) catch { _ => return None }
    if decoded.length() == bits / 8 {
      return Some(decoded)
    }
  }
  None
}

///|
fn untagged_spec(
  algorithm : Digest,
  value : String,
  modern : Bool,
) -> DigestSpec? {
  if algorithm is (Sha2 | Sha3 | Blake2b) {
    let hex = value.iter().all(c => c is ('0'..<='9' | 'a'..<='f' | 'A'..<='F'))
    let bits = if hex {
      value.length() * 4
    } else if modern {
      let decoded = @base64.decode(value[:]) catch { _ => return None }
      decoded.length() * 8
    } else {
      return None
    }
    if valid_width(algorithm, bits) {
      Some({ algorithm, bits, })
    } else {
      None
    }
  } else {
    Some({ algorithm, bits: algorithm.default_bits(), })
  }
}

///|
fn manifest_record(
  line : String,
  selected : Digest?,
  modern : Bool,
  format : ManifestFormat,
) -> ManifestRecord? {
  // GNU locks an explicit SHA2 selection to the first fixed SHA tag it reads.
  let selected = if selected is Some(Sha2) {
    Some(format.sha2_tag.unwrap_or(Sha2))
  } else {
    selected
  }
  let mut start = 0
  while start < line.length() && blank(line[start]) {
    start += 1
  }
  let escaped = start < line.length() && line[start] == '\\'
  if escaped {
    start += 1
  }
  let record = line[start:].to_owned()
  let mut spec : DigestSpec? = None
  let mut encoded_name = ""
  let mut digest = ""
  if record.find("(") is Some(open) {
    let raw_tag = record[:open].to_owned()
    let tag = if raw_tag.has_suffix(" ") {
      raw_tag[:raw_tag.length() - 1].to_owned()
    } else {
      raw_tag
    }
    if tagged_spec(tag, selected, modern) is Some(parsed) {
      if selected is Some(Sha2) {
        format.sha2_tag = Some(parsed.algorithm)
      }
      format.label = parsed.algorithm.label()
      let mut close = record.length() - 1
      while close > open && record[close] != ')' {
        close -= 1
      }
      if close <= open {
        return None
      }
      let mut tail = close + 1
      while tail < record.length() && blank(record[tail]) {
        tail += 1
      }
      if tail >= record.length() || record[tail] != '=' {
        return None
      }
      tail += 1
      while tail < record.length() && blank(record[tail]) {
        tail += 1
      }
      spec = Some(parsed)
      encoded_name = record[open + 1:close].to_owned()
      digest = record[tail:].to_owned()
    }
  }
  if spec is None {
    guard selected is Some(algorithm) else { return None }
    let mut end = 0
    while end < record.length() && !blank(record[end]) {
      end += 1
    }
    if end == record.length() {
      return None
    }
    digest = record[:end].to_owned()
    spec = untagged_spec(algorithm, digest, modern)
    guard spec is Some(parsed) else { return None }
    if decode_digest(digest, parsed.bits, modern) is None {
      return None
    }
    let mut name_start = end + 1
    if name_start >= record.length() {
      return None
    }
    let reversed = record.length() - name_start == 1 ||
      !(record[name_start] is (' ' | '*'))
    if reversed {
      if format.reversed == 0 {
        return None
      }
      format.reversed = 1
    } else if format.reversed != 1 {
      format.reversed = 0
      name_start += 1
    }
    encoded_name = record[name_start:].to_owned()
  }
  guard spec is Some(spec) else { return None }
  guard decode_digest(digest, spec.bits, modern) is Some(expected) else {
    return None
  }
  let name = if escaped {
    match decode_filename(encoded_name) {
      Some(name) => name
      None => return None
    }
  } else {
    encoded_name
  }
  if name.is_empty() || name.contains("\u0000") {
    return None
  }
  Some({ spec, expected, name, })
}

///|
fn output_record(
  spec : DigestSpec,
  bytes : Bytes,
  length : UInt64,
  source : String,
  implicit_stdin : Bool,
  tagged : Bool,
  binary : Bool,
  zero : Bool,
  base64 : Bool,
) -> String {
  let end = if zero { "\u0000" } else { "\n" }
  if spec.algorithm.legacy() {
    let number = legacy_number(bytes).to_string()
    let count = match spec.algorithm {
      Bsd =>
        (length / 1024UL + (if length % 1024UL != 0UL { 1UL } else { 0UL })).to_string()
      Sysv =>
        (length / 512UL + (if length % 512UL != 0UL { 1UL } else { 0UL })).to_string()
      _ => length.to_string()
    }
    let fields = if spec.algorithm is Bsd {
      "0".repeat((5 - number.length()).max(0)) +
      number +
      " " +
      " ".repeat((5 - count.length()).max(0)) +
      count
    } else {
      number + " " + count
    }
    return fields + (if implicit_stdin { "" } else { " " + source }) + end
  }
  let digest = if base64 { @base64.encode(bytes[:]) } else { hex_digest(bytes) }
  if !tagged {
    return format_record(digest, source, binary, zero)
  }
  let (name, escaped) = if zero {
    (source, false)
  } else {
    encode_filename(source)
  }
  (if escaped { "\\" } else { "" }) +
  "\{spec.tag()} (\{name}) = \{digest}\{end}"
}

///|
// Match the C-locale shell quoting used by GNU checksum verification results.
fn quote_name(name : String) -> String {
  let safe = !name.is_empty() &&
    name
    .iter()
    .all(c => {
      c
      is ('a'..<='z'
      | 'A'..<='Z'
      | '0'..<='9'
      | '_'
      | '-'
      | '.'
      | '/'
      | '+'
      | ','
      | ':'
      | '@'
      | '%')
    })
  if safe {
    return name
  }
  if name.contains("'") &&
    !name.contains("\"") &&
    !name.contains("\\") &&
    !name.contains("$") &&
    !name
    .iter()
    .any(c => c.to_int() < 32 || c.to_int() == 96 || c.to_int() == 127) {
    return "\"" + name + "\""
  }
  let output = StringBuilder()
  output.write_char('\'')
  for char in name {
    match char {
      '\'' => output.write_string("'\\''")
      '\n' => output.write_string("'$'\\n''")
      '\r' => output.write_string("'$'\\r''")
      '\t' => output.write_string("'$'\\t''")
      _ => output.write_char(char)
    }
  }
  output.write_char('\'')
  output.to_string()
}
