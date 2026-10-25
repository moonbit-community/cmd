///|
priv struct TreeColors {
  codes : Map[String, String]
  suffixes : Array[(String, String)]
}

///|
priv struct TreeOutput {
  pending : @buffer.Buffer
  send : async (Bytes) -> Unit
}

///|
fn TreeOutput::new(send : async (Bytes) -> Unit) -> TreeOutput {
  { pending: @buffer.Buffer(), send, }
}

///|
async fn TreeOutput::flush(self : TreeOutput) -> Unit {
  if !self.pending.is_empty() {
    (self.send)(self.pending.to_bytes())
    self.pending.reset()
  }
}

///|
async fn TreeOutput::write(self : TreeOutput, text : String) -> Unit {
  self.pending.write_string_utf8(text)
  if self.pending.length() >= 65536 {
    self.flush()
  }
}

///|
fn tree_colors(force : Bool) -> TreeColors? {
  if !force || @env.get_env_var("TERM") is None {
    return None
  }
  let value = @env.get_env_var("TREE_COLORS").unwrap_or_else(() => {
    @env.get_env_var("LS_COLORS").unwrap_or("")
  })
  let value = if value == "" {
    "no=00:rs=0:fi=00:di=01;34:ln=01;36:pi=40;33:so=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32"
  } else {
    value
  }
  let codes : Map[String, String] = Map([])
  let suffixes : Array[(String, String)] = []
  for field in value.split(":") {
    let parts = field.split("=").filter(part => !part.is_empty()).collect()
    if parts.length() < 2 {
      continue
    }
    let key = parts[0].to_owned()
    let sequence = parts[1].to_owned()
    if key.has_prefix("*") {
      suffixes.push((key[1:].to_owned(), sequence))
    } else {
      codes[key] = sequence
    }
  }
  suffixes.rev_in_place()
  if !codes.contains("lc") {
    codes["lc"] = "\u001b["
  }
  if !codes.contains("rc") {
    codes["rc"] = "m"
  }
  if !codes.contains("rs") {
    codes["rs"] = "0"
  }
  if !codes.contains("ec") {
    codes["ec"] = codes["lc"] + codes["rs"] + codes["rc"]
  }
  Some({ codes, suffixes, })
}

///|
fn require_color_kind(
  kind : @fs.FileKind,
  colors : TreeColors,
) -> Unit raise TreeError {
  let selectors = match kind {
    Regular => ["su", "sg", "ex"]
    Directory => ["tw", "ow", "st"]
    _ => []
  }
  let unknown = selectors.filter(selector => colors.codes.contains(selector))
  if !unknown.is_empty() {
    raise TreeError(
      "color selectors " +
      unknown.join(",") +
      " require unavailable raw mode bits; omit these TREE_COLORS selectors",
    )
  }
}

///|
fn tree_color(
  kind : @fs.FileKind,
  name : String,
  colors : TreeColors,
) -> String? {
  if kind == Regular {
    for (suffix, sequence) in colors.suffixes {
      if name.has_suffix(suffix) {
        return Some(sequence)
      }
    }
  }
  let code = match kind {
    Directory => "di"
    Regular => "fi"
    SymLink => "ln"
    Pipe => "pi"
    Socket => "so"
    BlockDevice => "bd"
    CharDevice => "cd"
    _ => "no"
  }
  colors.codes.get(code)
}

///|
fn c_name(value : String) -> String {
  let output = StringBuilder()
  for byte in @utf8.encode(value) {
    let simple = match byte {
      7 => Some('a')
      8 => Some('b')
      9 => Some('t')
      10 => Some('n')
      11 => Some('v')
      12 => Some('f')
      13 => Some('r')
      b'\\' => Some('\\')
      b' ' => Some(' ')
      _ => None
    }
    match simple {
      Some(c) => {
        output.write_char('\\')
        output.write_char(c)
      }
      None => {
        let code = byte.to_int()
        if byte >= 32 && byte < 127 {
          output.write_char(code.unsafe_to_char())
        } else {
          output.write_char('\\')
          output.write_char((48 + code / 64).unsafe_to_char())
          output.write_char((48 + code / 8 % 8).unsafe_to_char())
          output.write_char((48 + code % 8).unsafe_to_char())
        }
      }
    }
  }
  output.to_string()
}

///|
fn left_pad(value : String, width : Int32) -> String {
  " ".repeat((width - value.length()).max(0)) + value
}

///|
fn size_text(size : Int64, style : SizeStyle) -> String {
  if style == ExactSize {
    return " " + left_pad(size.to_string(), 11)
  }
  let base = if style == SiSize { 1000L } else { 1024L }
  let mut reduced = size
  let mut index = if size < base { 0 } else { 1 }
  while reduced >= base * base {
    reduced /= base
    index += 1
  }
  if index == 0 {
    return " " + left_pad(reduced.to_string(), 4)
  }
  let number = Float::from_int64(reduced) / Float::from_int64(base)
  let precision = if (reduced + 52L) / base >= 10L { 0 } else { 1 }
  let text = human_decimal(number, precision)
  let units = if style == SiSize { "dkMGTPEZY" } else { "BKMGTPEZY" }
  " " + left_pad(text, 3) + units[index:index + 1].to_owned()
}

///|
// psize only formats positive float32 quotients below 1024 to 0 or 1 decimals.
fn human_decimal(value : Float, precision : Int32) -> String {
  let bits = value.reinterpret_as_uint()
  let significant = ((bits & 0x7FFFFFU) | 0x800000U).to_uint64()
  let scaled = significant * (if precision == 1 { 10UL } else { 1UL })
  let divisor = 1UL << (150 - ((bits >> 23) & 0xFFU).reinterpret_as_int())
  let mut rounded = scaled / divisor
  let remainder = scaled % divisor
  if remainder * 2UL > divisor ||
    (remainder * 2UL == divisor && rounded % 2UL != 0UL) {
    rounded += 1UL
  }
  if precision == 0 {
    rounded.to_string()
  } else {
    (rounded / 10UL).to_string() + "." + (rounded % 10UL).to_string()
  }
}

///|
fn node_note(node : TreeNode, options : TreeOptions, root : Bool) -> String? {
  if root && (options.prune || options.disk_usage) && node.limited {
    Some("error opening dir")
  } else {
    node.note
  }
}

///|
fn write_text_label(
  node : TreeNode,
  options : TreeOptions,
  root : Bool,
  out : StringBuilder,
) -> Unit {
  if node.size is Some(size) {
    out.write_string("[" + size_text(size, options.size)[1:].to_owned() + "]  ")
  }
  let sequence = match options.colors {
    Some(colors) =>
      tree_color(node.kind, if root { "" } else { node.name }, colors)
    None => None
  }
  if sequence is Some(sequence) && options.colors is Some(colors) {
    out.write_string(colors.codes["lc"] + sequence + colors.codes["rc"])
  }
  out.write_string(c_name(node_label(node, options, root)))
  if sequence is Some(_) && options.colors is Some(colors) {
    out.write_string(colors.codes["ec"])
  }
  if node_note(node, options, root) is Some(note) {
    out.write_string("  [" + note + "]")
  }
}
