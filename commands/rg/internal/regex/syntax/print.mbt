///|
fn write_char_escaped(buf : StringBuilder, c : Int32) -> Unit {
  if c <= 0x7F && is_meta_character(c.unsafe_to_char()) {
    buf.write_char('\\')
    buf.write_char(c.unsafe_to_char())
  } else if c < 0x20 || c == 0x7F {
    buf.write_string("\\x")
    buf.write_string(hex2(c))
  } else if c > 0x7F && c <= 0x10FFFF && !(c >= 0xD800 && c <= 0xDFFF) {
    buf.write_char(c.unsafe_to_char())
  } else if c <= 0x7F {
    buf.write_char(c.unsafe_to_char())
  } else {
    buf.write_string("\\x{")
    buf.write_string(c.to_string(radix=16))
    buf.write_string("}")
  }
}

///|
fn hex2(c : Int32) -> String {
  let s = c.to_string(radix=16).to_upper()
  if s.length() < 2 {
    "0" + s
  } else {
    s
  }
}

///|
fn write_byte_escaped(buf : StringBuilder, b : Int32) -> Unit {
  if b <= 0x7F && b >= 0x20 && b != 0x7F {
    write_char_escaped(buf, b)
  } else {
    buf.write_string("\\x")
    buf.write_string(hex2(b))
  }
}

///|
fn print_hir(buf : StringBuilder, h : Hir) -> Unit {
  match h.kind {
    Empty => buf.write_string("(?:)")
    Literal(bytes) =>
      if is_valid_utf8(bytes) {
        let s = @utf8.decode_lossy(bytes)
        for c in s {
          write_char_escaped(buf, c.to_int())
        }
      } else {
        buf.write_string("(?-u:")
        for b in bytes {
          write_byte_escaped(buf, b.to_int())
        }
        buf.write_string(")")
      }
    Class(Unicode(ranges)) => {
      buf.write_char('[')
      for r in ranges {
        write_char_escaped(buf, r.0)
        if r.0 != r.1 {
          buf.write_char('-')
          write_char_escaped(buf, r.1)
        }
      }
      buf.write_char(']')
    }
    Class(Bytes(ranges)) => {
      buf.write_string("(?-u:[")
      for r in ranges {
        write_byte_escaped(buf, r.0)
        if r.0 != r.1 {
          buf.write_char('-')
          write_byte_escaped(buf, r.1)
        }
      }
      buf.write_string("])")
    }
    Look(look) =>
      buf.write_string(
        match look {
          Start => "\\A"
          End => "\\z"
          StartLF => "(?m:^)"
          EndLF => "(?m:$)"
          StartCRLF => "(?mR:^)"
          EndCRLF => "(?mR:$)"
          WordAscii => "(?-u:\\b)"
          WordAsciiNegate => "(?-u:\\B)"
          WordUnicode => "\\b"
          WordUnicodeNegate => "\\B"
          WordStartAscii => "(?-u:\\b{start})"
          WordEndAscii => "(?-u:\\b{end})"
          WordStartUnicode => "\\b{start}"
          WordEndUnicode => "\\b{end}"
          WordStartHalfAscii => "(?-u:\\b{start-half})"
          WordEndHalfAscii => "(?-u:\\b{end-half})"
          WordStartHalfUnicode => "\\b{start-half}"
          WordEndHalfUnicode => "\\b{end-half}"
        },
      )
    Repetition(min~, max~, greedy~, sub) => {
      match sub.kind {
        Literal(b) if b.length() > 1 => {
          buf.write_string("(?:")
          print_hir(buf, sub)
          buf.write_string(")")
        }
        Concat(_) | Alternation(_) => {
          buf.write_string("(?:")
          print_hir(buf, sub)
          buf.write_string(")")
        }
        _ => print_hir(buf, sub)
      }
      match (min, max) {
        (0, Some(1)) => buf.write_string("?")
        (0, None) => buf.write_string("*")
        (1, None) => buf.write_string("+")
        (m, Some(n)) if m == n => buf.write_string("{\{m}}")
        (m, None) => buf.write_string("{\{m},}")
        (m, Some(n)) => buf.write_string("{\{m},\{n}}")
      }
      if !greedy {
        buf.write_string("?")
      }
    }
    Capture(name~, sub, ..) => {
      match name {
        Some(n) => buf.write_string("(?P<\{n}>")
        None => buf.write_string("(")
      }
      print_hir(buf, sub)
      buf.write_string(")")
    }
    Concat(xs) =>
      for x in xs {
        match x.kind {
          Alternation(_) => {
            buf.write_string("(?:")
            print_hir(buf, x)
            buf.write_string(")")
          }
          _ => print_hir(buf, x)
        }
      }
    Alternation(xs) =>
      for i, x in xs {
        if i > 0 {
          buf.write_char('|')
        }
        print_hir(buf, x)
      }
  }
}

///|
/// Renders the HIR as a regular expression string.
pub fn Hir::to_string(self : Hir) -> String {
  let buf = StringBuilder()
  print_hir(buf, self)
  buf.to_string()
}

///|
pub impl Show for Hir with fn output(self, logger) {
  logger.write_string(self.to_string())
}
