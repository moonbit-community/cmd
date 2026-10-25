///|
priv struct ColorSuffix {
  suffix : Bytes
  sequence : Bytes
  mut exact : Bool
  mut ignored : Bool
}

///|
priv struct Palette {
  codes : Map[String, Bytes]
  suffixes : Array[ColorSuffix]
}

///|
fn active(palette : Palette, key : String) -> Bool {
  match palette.codes.get(key) {
    Some(value) => value != b"" && value != b"0" && value != b"00"
    None => false
  }
}

///|
fn color_sequence(palette : Palette, sequence : Bytes) -> Bytes {
  palette.codes["lc"] + sequence + palette.codes["rc"]
}

///|
fn color_reset(palette : Palette) -> Bytes {
  palette.codes
  .get("ec")
  .unwrap_or_else(() => color_sequence(palette, palette.codes["rs"]))
}

///|
fn defaults() -> Palette {
  {
    codes: {
      "lc": b"\x1b[",
      "rc": b"m",
      "rs": b"0",
      "di": b"01;34",
      "ln": b"01;36",
      "pi": b"33",
      "so": b"01;35",
      "bd": b"01;33",
      "cd": b"01;33",
      "ex": b"01;32",
      "do": b"01;35",
      "su": b"37;41",
      "sg": b"30;43",
      "st": b"37;44",
      "ow": b"34;42",
      "tw": b"30;42",
      "cl": b"\x1b[K",
    },
    suffixes: [],
  }
}

///|
fn color_part(bytes : Bytes, start : Int32, equals : Bool) -> (Bytes, Int32)? {
  let out : Array[Byte] = []
  let mut index = start
  while index < bytes.length() &&
        bytes[index] != b':' &&
        !(equals && bytes[index] == b'=') {
    let byte = bytes[index]
    index += 1
    if byte == b'\\' {
      guard index < bytes.length() else { return None }
      let code = bytes[index]
      index += 1
      if code is (b'0'..<=b'7' | b'x' | b'X') {
        let base = if code is (b'x' | b'X') { 16 } else { 8 }
        let mut value = if base == 16 { 0 } else { code.to_int() - 48 }
        while index < bytes.length() {
          let digit = match bytes[index] {
            b'0'..<=b'9' as b => b.to_int() - 48
            b'a'..<=b'f' as b => b.to_int() - 87
            b'A'..<=b'F' as b => b.to_int() - 55
            _ => -1
          }
          if digit < 0 || digit >= base {
            break
          }
          value = (value * base + digit) % 256
          index += 1
        }
        out.push(value.to_byte())
      } else {
        out.push(
          match code {
            b'a' => 7
            b'b' => 8
            b'e' => 27
            b'f' => 12
            b'n' => 10
            b'r' => 13
            b't' => 9
            b'v' => 11
            b'?' => 127
            b'_' => b' '
            _ => code
          },
        )
      }
    } else if byte == b'^' {
      guard index < bytes.length() else { return None }
      let code = bytes[index]
      index += 1
      if code == b'?' {
        out.push(127)
      } else if code >= b'@' && code <= b'~' {
        out.push((code.to_int() & 31).to_byte())
      } else {
        return None
      }
    } else {
      out.push(byte)
    }
  }
  Some((Bytes::from_array(out), index))
}

///|
fn ascii_lower(value : Bytes) -> Bytes {
  Bytes::makei(value.length(), i => {
    if value[i] >= b'A' && value[i] <= b'Z' {
      (value[i].to_int() + 32).to_byte()
    } else {
      value[i]
    }
  })
}

///|
fn parse_colors(value : String) -> (Palette?, String) {
  let palette = defaults()
  let bytes = @utf8.encode(value)
  let mut index = 0
  let mut reason = ""
  while index < bytes.length() {
    if bytes[index] == b':' {
      index += 1
      continue
    }
    if bytes[index] == b'*' {
      guard color_part(bytes, index + 1, true) is Some((suffix, end)) &&
        end < bytes.length() &&
        bytes[end] == b'=' &&
        color_part(bytes, end + 1, false) is Some((sequence, next)) else {
        reason = "invalid"
        break
      }
      palette.suffixes.push({ suffix, sequence, exact: false, ignored: false, })
      index = next
    } else {
      guard index + 2 < bytes.length() && bytes[index + 2] == b'=' else {
        reason = "invalid"
        break
      }
      let label = @utf8.decode_lossy(bytes[index:index + 2].to_owned())
      guard [
        "lc", "rc", "ec", "rs", "no", "fi", "di", "ln", "pi", "so", "bd", "cd", "mi",
        "or", "ex", "do", "su", "sg", "st", "ow", "tw", "ca", "mh", "cl",
      ].contains(label) else {
        reason = "ls: unrecognized prefix: " +
          @quoting.locale_quote(bytes[index:index + 2]) +
          "\n"
        break
      }
      guard color_part(bytes, index + 3, false) is Some((sequence, next)) else {
        reason = "invalid"
        break
      }
      palette.codes[label] = sequence
      index = next
    }
  }
  if reason != "" {
    return (
      None,
      (if reason == "invalid" { "" } else { reason }) +
      "ls: unparsable value for LS_COLORS environment variable\n",
    )
  }
  palette.suffixes.rev_in_place()
  for index, first in palette.suffixes {
    let mut case_ignored = false
    for next = index + 1; next < palette.suffixes.length(); next = next + 1 {
      let second = palette.suffixes[next]
      if second.ignored {
        continue
      }
      if first.suffix == second.suffix {
        second.ignored = true
      } else if ascii_lower(first.suffix) == ascii_lower(second.suffix) {
        if case_ignored {
          second.ignored = true
        } else if first.sequence == second.sequence {
          second.ignored = true
          case_ignored = true
        } else {
          first.exact = true
          second.exact = true
        }
      }
    }
  }
  (Some(palette), "")
}

///|
fn color_palette(enabled : Bool) -> (Palette?, String) {
  if !enabled {
    return (None, "")
  }
  let value = @env.get_env_var("LS_COLORS").unwrap_or("")
  if value != "" {
    return parse_colors(value)
  }
  let term = @env.get_env_var("TERM").unwrap_or("")
  let colorterm = @env.get_env_var("COLORTERM").unwrap_or("")
  let con = @utf8.encode(term)
  let known_console = con.length() > 4 &&
    term.has_prefix("con") &&
    con[3] is (b'0'..<=b'9') &&
    ({
      let mut found = false
      for i = 4; i + 1 < con.length(); i = i + 1 {
        if con[i] == b'x' && con[i + 1] is (b'0'..<=b'9') {
          found = true
        }
      }
      found
    })
  let known = term.has_prefix("xterm") ||
    term.has_prefix("screen") ||
    term.has_prefix("tmux") ||
    term.has_prefix("rxvt") ||
    term.contains("color") ||
    term.contains("direct") ||
    known_console ||
    [
      "Eterm", "ansi", "cons25", "console", "cygwin", "dtterm", "gnome", "hurd",
      "jfbterm", "konsole", "kterm", "linux", "linux-c", "mlterm", "putty", "st",
      "terminator", "vt100", "vt220",
    ].contains(term)
  (if colorterm != "" || known { Some(defaults()) } else { None }, "")
}

///|
fn require_color_metadata(
  kind : @fs.FileKind?,
  palette : Palette,
) -> Unit raise @fsops.FsOpError {
  let keys = match kind {
    Some(Regular) => ["su", "sg", "ca", "ex", "mh"]
    Some(Directory) => ["tw", "ow", "st"]
    _ => []
  }
  let required = keys.filter(key => active(palette, key))
  if !required.is_empty() {
    raise @fsops.FsOpError(
      "color selectors " +
      required.join(",") +
      " require unavailable mode, capability or link-count metadata; disable those LS_COLORS selectors",
    )
  }
}

///|
async fn entry_color(entry : LsEntry, palette : Palette) -> Bytes? {
  let mut kind = entry.kind
  let mut orphan = false
  if kind == Some(SymLink) &&
    (palette.codes.get("ln") == Some(b"target") || active(palette, "or")) {
    let target = try @fs.kind(entry.path, follow_symlink=true) catch {
      @os_error.OSError(_) as error if error.is_ENOENT() ||
        is_symlink_loop(error) => None
      error => raise error
    } noraise {
      target => Some(target)
    }
    orphan = target is None
    if palette.codes.get("ln") == Some(b"target") {
      kind = target
    }
  }
  require_color_metadata(kind, palette)
  let label = if orphan {
    "or"
  } else {
    match kind {
      Some(Regular) => "fi"
      Some(Directory) => "di"
      Some(SymLink) => "ln"
      Some(Pipe) => "pi"
      Some(Socket) => "so"
      Some(BlockDevice) => "bd"
      Some(CharDevice) => "cd"
      _ => "or"
    }
  }
  if label == "fi" {
    for item in palette.suffixes {
      if item.ignored {
        continue
      }
      let name = @utf8.encode(entry.name)
      if item.suffix.length() <= name.length() {
        let tail = name[name.length() - item.suffix.length():].to_owned()
        if (if item.exact {
            tail == item.suffix
          } else {
            ascii_lower(tail) == ascii_lower(item.suffix)
          }) {
          return Some(item.sequence)
        }
      }
    }
  }
  palette.codes.get(label)
}
