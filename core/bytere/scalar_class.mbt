///|
priv enum ScalarTerm {
  Range(Char, Char)
  Named(String)
}

///|
priv struct ScalarSet {
  terms : Array[ScalarTerm]
  extra_upper : Set[Char]
  fold : Bool
  invert : Bool
}

///|
fn scalar_alpha(c : Char) -> Bool {
  @unicode.is_alphabetic(c) ||
  (!c.is_ascii() && @unicode.general_category(c) is Nd)
}

///|
fn scalar_word(c : Char?) -> Bool {
  c is Some(ch) && (ch == '_' || ch.is_ascii_digit() || scalar_alpha(ch))
}

///|
fn scalar_class(name : String, c : Char, fold : Bool) -> Bool {
  let blank = @textwidth.is_blank(Some(c))
  let space = blank || c is ('\n'..<'\r' | '\r' | '\u2028' | '\u2029')
  match name {
    "alpha" => scalar_alpha(c)
    "alnum" => c.is_ascii_digit() || scalar_alpha(c)
    "word" => scalar_word(Some(c))
    "digit" => c.is_ascii_digit()
    "xdigit" => c.is_ascii_hexdigit()
    "space" => space
    "blank" => blank
    "cntrl" => c.is_control() || c == '\u2028' || c == '\u2029'
    "lower" | "upper" => {
      let lower = @unicode.is_lowercase(c) ||
        @unicode.to_simple_uppercase(c) != c
      let upper = @unicode.is_uppercase(c) ||
        @unicode.to_simple_lowercase(c) != c
      if fold {
        lower || upper
      } else if name == "lower" {
        lower
      } else {
        upper
      }
    }
    _ => {
      let printable = !(@unicode.general_category(c) is (Cn | Cs | Cc | Zl | Zp))
      let graphic = printable && !space
      match name {
        "print" => printable
        "graph" => graphic
        _ => graphic && !c.is_ascii_digit() && !scalar_alpha(c)
      }
    }
  }
}

///|
fn ScalarSet::new(
  terms : Array[ScalarTerm],
  fold : Bool,
  invert : Bool,
) -> ScalarSet {
  let extra_upper : Set[Char] = Set([])
  if fold {
    for term in terms {
      if term is Range(first, last) {
        for n in first.to_int()..<=last.to_int() {
          if n.to_char() is Some(c) {
            let upper = @unicode.to_simple_uppercase(c)
            if upper < first || upper > last {
              extra_upper.insert(upper)
            }
          }
        }
      }
    }
  }
  { terms, extra_upper, fold, invert, }
}

///|
fn ScalarSet::contains(self : ScalarSet, ch : Char?) -> Bool {
  guard ch is Some(c) else { return false }
  let upper = if self.fold { @unicode.to_simple_uppercase(c) } else { c }
  for term in self.terms {
    let found = match term {
      Range(a, b) =>
        (a <= c && c <= b) || (self.fold && a <= upper && upper <= b)
      Named(name) => scalar_class(name, c, self.fold)
    }
    if found {
      return !self.invert
    }
  }
  self.extra_upper.contains(upper) != self.invert
}
