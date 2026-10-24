///|
pub(all) suberror PatternError {
  PatternError(String)
}

///|
/// A reversible one-code-unit-per-byte view for C-locale text algorithms.
pub fn text(data : BytesView) -> String {
  let out = StringBuilder()
  for b in data {
    out.write_char(b.to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
pub fn bytes(value : StringView) -> Bytes {
  Bytes::from_array(value.iter().map(c => c.to_int().to_byte()).collect())
}

///|
pub fn argument(value : String) -> String {
  text(@utf8.encode(value))
}

///|
struct Pattern {
  program : Array[Instruction]
  entry : Int32
  groups : Int32
  backreferences : Bool
  ignore_case : Bool
  literal : LiteralPattern?
  prefix : String
}

///|
priv struct LiteralPattern {
  text : String
  begin : Bool
  end : Bool
}

///|
pub(all) struct Hit {
  start : Int32
  end : Int32
  groups : Array[String?]
}

///|
pub fn compile(
  pattern : String,
  extended~ : Bool = false,
  grep_syntax~ : Bool = false,
  ignore_case~ : Bool = false,
) -> Pattern raise {
  let parser = Parser::{
    source: pattern,
    extended,
    grep_syntax,
    ignore_case,
    index: 0,
    closed: [],
    backreferences: false,
    depth: 0,
  }
  let tree = parser.expression()
  guard parser.index == pattern.length() else {
    raise PatternError("unmatched closing parenthesis")
  }
  let program = [Instruction::Accept]
  let entry = tree.emit(program, 0)
  if parser.backreferences {
    let nullable = Array::make(parser.closed.length(), false)
    ignore(tree.nullable(nullable))
    let closings = Array::make(parser.closed.length(), 0)
    let referenced = Array::make(parser.closed.length(), false)
    for instruction in program {
      match instruction {
        Save(slot, _) => if slot % 2 == 1 { closings[slot / 2] += 1 }
        SaveOptional(group, _) => closings[group] += 1
        Reference(group, _) => referenced[group] = true
        _ => ()
      }
    }
    for group in 0..<nullable.length() {
      if nullable[group] && closings[group] > 1 && referenced[group] {
        raise PatternError(
          "backreference to a cloned nullable capture is unsupported",
        )
      }
    }
  }
  let prefix = StringBuilder()
  ignore(tree.literal_prefix(prefix))
  {
    program,
    entry,
    groups: parser.closed.length(),
    backreferences: parser.backreferences,
    ignore_case,
    literal: tree.literal_pattern(),
    prefix: prefix.to_string(),
  }
}

///|
pub fn Pattern::group_count(self : Pattern) -> Int32 {
  self.groups
}

///|
/// Choose the earliest start, then the longest match. Captured strings are
/// allocated only after the winning byte spans have been selected.
pub fn Pattern::find(
  self : Pattern,
  value : String,
  start~ : Int32 = 0,
) -> Hit? {
  self
  .search(value, start, false, false, true)
  .map(result => {
    let groups : Array[String?] = [
      Some(value[result.start:result.end].to_owned()),
    ]
    for group in 0..<self.groups {
      let left = result.captures[group * 2]
      let right = result.captures[group * 2 + 1]
      groups.push(
        if left >= 0 && right >= left {
          Some(value[left:right].to_owned())
        } else {
          None
        },
      )
    }
    { start: result.start, end: result.end, groups, }
  })
}

///|
/// Search without allocating captured strings. Whole-record and word filters
/// apply to each accepting state, including shorter alternatives at one start.
pub fn Pattern::find_span(
  self : Pattern,
  value : String,
  start~ : Int32 = 0,
  whole~ : Bool = false,
  word~ : Bool = false,
) -> (Int32, Int32)? {
  self.search(value, start, whole, word, false).map(hit => (hit.start, hit.end))
}
