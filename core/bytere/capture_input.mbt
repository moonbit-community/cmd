///|
/// GNU's capture pruning operates on character positions. Byte expressions
/// address the reversible byte string; C.UTF-8 expressions address scalars.
priv enum CaptureInput {
  ByteText(StringView)
  ScalarText(Utf8Record, Array[ScalarSet])
}

///|
fn CaptureInput::length(self : CaptureInput) -> Int32 {
  match self {
    ByteText(text) => text.length()
    ScalarText(r, _) => r.chars.length()
  }
}

///|
fn CaptureInput::assertion(
  self : CaptureInput,
  a : Assertion,
  at : Int32,
) -> Bool {
  match self {
    ByteText(text) => a.holds(text, at)
    ScalarText(r, _) => r.assertion(a, at)
  }
}

///|
fn CaptureInput::accepts(
  self : CaptureInput,
  start : Int32,
  end : Int32,
  whole : Bool,
  word : Bool,
) -> Bool {
  match self {
    ByteText(text) => accepted(text, start, end, whole, word)
    ScalarText(r, _) =>
      (!whole || (start == 0 && end == r.chars.length())) &&
      (
        !word ||
        (
          (start == 0 || !r.words[start - 1]) &&
          (end == r.chars.length() || !r.words[end])
        )
      )
  }
}

///|
fn CaptureInput::consume(
  self : CaptureInput,
  instruction : Instruction,
  at : Int32,
) -> Int32? {
  match (self, instruction) {
    (ByteText(text), Byte(code, next)) if text[at].to_int() == code =>
      Some(next)
    (ByteText(text), Class(members, next)) if text[at].to_int() < 256 &&
      members[text[at].to_int()] => Some(next)
    (ByteText(_), Any(next)) => Some(next)
    (ScalarText(r, sets), Byte(id, next)) if sets[id].contains(r.chars[at]) =>
      Some(next)
    (ScalarText(r, _), Any(next)) if r.chars[at] is Some(_) => Some(next)
    _ => None
  }
}

///|
fn equal_reference(
  value : CaptureInput,
  left : Int32,
  right : Int32,
  position : Int32,
  fold : Bool,
) -> Bool {
  guard right - left <= value.length() - position else { return false }
  match value {
    ByteText(text) => {
      if !fold {
        return text[left:right] == text[position:position + right - left]
      }
      for i in 0..<(right - left) {
        if ascii_fold(text[left + i].to_int()) !=
          ascii_fold(text[position + i].to_int()) {
          return false
        }
      }
    }
    ScalarText(r, _) =>
      for i in 0..<(right - left) {
        let a = r.chars[left + i]
        let b = r.chars[position + i]
        if a != b &&
          !(fold &&
          a is Some(x) &&
          b is Some(y) &&
          @unicode.to_simple_uppercase(x) == @unicode.to_simple_uppercase(y)) {
          return false
        }
      }
  }
  true
}
