///|
/// Removes the line terminator from anything in the HIR that could match
/// it. Returns an error if a literal containing the terminator is found.
fn strip_from_match(
  expr : @syntax.Hir,
  line_term : @matcher.LineTerminator,
) -> @syntax.Hir raise GrepRegexError {
  if line_term.is_crlf() {
    let expr1 = strip_from_match_ascii(expr, b'\r')
    strip_from_match_ascii(expr1, b'\n')
  } else {
    strip_from_match_ascii(expr, line_term.as_byte())
  }
}

///|
fn strip_from_match_ascii(
  expr : @syntax.Hir,
  byte : Byte,
) -> @syntax.Hir raise GrepRegexError {
  if byte.to_int() > 0x7F {
    raise GrepRegexError(InvalidLineTerminator(byte))
  }
  let ch = byte.to_int().unsafe_to_char()
  let invalid = () => GrepRegexError(NotAllowed(ch.to_string()))
  match expr.kind {
    Empty => @syntax.Hir::empty()
    Literal(lit) => {
      for b in lit {
        if b == byte {
          raise invalid()
        }
      }
      @syntax.Hir::literal(lit)
    }
    Class(cls) => {
      if cls.is_empty() {
        return @syntax.Hir::class(cls)
      }
      let remove = match cls {
        Unicode(_) => @syntax.Class::Unicode([(byte.to_int(), byte.to_int())])
        Bytes(_) => @syntax.Class::Bytes([(byte.to_int(), byte.to_int())])
      }
      let cls = cls.difference(remove)
      if cls.is_empty() {
        raise invalid()
      }
      @syntax.Hir::class(cls)
    }
    Look(x) => @syntax.Hir::look(x)
    Repetition(min~, max~, greedy~, sub) =>
      @syntax.Hir::repetition(
        min,
        max,
        greedy,
        strip_from_match_ascii(sub, byte),
      )
    Capture(index~, name~, sub) =>
      @syntax.Hir::capture(index, name, strip_from_match_ascii(sub, byte))
    Concat(xs) => {
      let out = []
      for x in xs {
        out.push(strip_from_match_ascii(x, byte))
      }
      @syntax.Hir::concat(out)
    }
    Alternation(xs) => {
      let out = []
      for x in xs {
        out.push(strip_from_match_ascii(x, byte))
      }
      @syntax.Hir::alternation(out)
    }
  }
}

///|
/// Returns an error if the given HIR could only ever match the banned byte
/// in a position where it would be impossible to match.
fn ban_check(expr : @syntax.Hir, byte : Byte) -> Unit raise GrepRegexError {
  let invalid = () => GrepRegexError(Banned(byte))
  match expr.kind {
    Empty | Look(_) => ()
    Literal(lit) =>
      for b in lit {
        if b == byte {
          raise invalid()
        }
      }
    Class(cls) => {
      let mut count = 0
      for r in cls.ranges() {
        count += r.1 - r.0 + 1
      }
      if count == 1 {
        let b = byte.to_int()
        for r in cls.ranges() {
          if r.0 <= b && b <= r.1 {
            raise invalid()
          }
        }
      }
    }
    Repetition(sub, ..) => ban_check(sub, byte)
    Capture(sub, ..) => ban_check(sub, byte)
    Concat(xs) | Alternation(xs) =>
      for x in xs {
        ban_check(x, byte)
      }
  }
}

///|
/// Returns the set of bytes that can never appear in a match.
fn non_matching_bytes(expr : @syntax.Hir) -> @matcher.ByteSet {
  let set = @matcher.ByteSet::full()
  remove_matching_bytes(expr, set)
  set
}

///|
fn remove_matching_bytes(expr : @syntax.Hir, set : @matcher.ByteSet) -> Unit {
  match expr.kind {
    Empty => ()
    Look(look) =>
      match look {
        Start | End | StartLF | EndLF => set.remove(b'\n')
        StartCRLF | EndCRLF => {
          set.remove(b'\r')
          set.remove(b'\n')
        }
        _ => ()
      }
    Literal(lit) =>
      for b in lit {
        set.remove(b)
      }
    Class(Unicode(ranges)) =>
      for r in ranges {
        for seq in @automata.utf8_sequences(r.0, r.1) {
          for br in seq {
            set.remove_all(br.0.to_byte(), br.1.to_byte())
          }
        }
      }
    Class(Bytes(ranges)) =>
      for r in ranges {
        set.remove_all(r.0.to_byte(), r.1.to_byte())
      }
    Repetition(sub, ..) => remove_matching_bytes(sub, set)
    Capture(sub, ..) => remove_matching_bytes(sub, set)
    Concat(xs) | Alternation(xs) =>
      for x in xs {
        remove_matching_bytes(x, set)
      }
  }
}
