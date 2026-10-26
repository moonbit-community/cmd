///|
/// Errors that can occur when looking up a Unicode class.
pub(all) suberror UnicodeError {
  PropertyNotFound
  PropertyValueNotFound
} derive(Debug, Eq)

///|
/// Decodes a compact range table produced by `scripts/gen_unicode.py`.
fn decode_ranges(s : String) -> Array[(Int32, Int32)] {
  let out = []
  let mut prev = 0
  let mut acc = 0
  let mut pending : Int32? = None
  for i in 0..<s.length() {
    let c = s.code_unit_at(i).to_int()
    if c < 0x50 {
      acc = (acc << 5) | (c - 0x30)
    } else {
      let n = (acc << 5) | (c - 0x50)
      acc = 0
      match pending {
        None => pending = Some(n)
        Some(d) => {
          let start = prev + d
          let end = start + n
          out.push((start, end))
          prev = end
          pending = None
        }
      }
    }
  }
  out
}

///|
fn decode_nums(s : String) -> Array[Int32] {
  let out = []
  let mut acc = 0
  for i in 0..<s.length() {
    let c = s.code_unit_at(i).to_int()
    if c < 0x50 {
      acc = (acc << 5) | (c - 0x30)
    } else {
      out.push((acc << 5) | (c - 0x50))
      acc = 0
    }
  }
  out
}

///|
fn find_table(data : Array[(String, String)], name : String) -> String? {
  for entry in data {
    if entry.0 == name {
      return Some(entry.1)
    }
  }
  None
}

///|
/// Lexicographic comparison by UTF-16 code units (the tables are ASCII).
fn lex_compare(a : String, b : String) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let x = a.code_unit_at(i).to_int()
    let y = b.code_unit_at(i).to_int()
    if x != y {
      return x - y
    }
  }
  a.length() - b.length()
}

///|
fn sorted_lookup(data : Array[(String, String)], key : String) -> String? {
  let mut lo = 0
  let mut hi = data.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let c = lex_compare(data[mid].0, key)
    if c == 0 {
      return Some(data[mid].1)
    } else if c < 0 {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  None
}

///|
/// Normalizes a property name or value following UAX44-LM3 loose matching,
/// exactly as regex-syntax does it.
pub fn symbolic_name_normalize(x : String) -> String {
  let bytes = []
  for c in x {
    let code = c.to_int()
    if code < 0x80 {
      bytes.push(code)
    }
  }
  let mut start = 0
  let mut starts_with_is = false
  if bytes.length() >= 2 &&
    (bytes[0] == 'i' || bytes[0] == 'I') &&
    (bytes[1] == 's' || bytes[1] == 'S') {
    starts_with_is = true
    start = 2
  }
  let out = StringBuilder()
  let mut n = 0
  for i in start..<bytes.length() {
    let b = bytes[i]
    if b == ' ' || b == '_' || b == '-' {
      continue
    } else if b >= 'A' && b <= 'Z' {
      out.write_char((b + 32).unsafe_to_char())
      n += 1
    } else {
      out.write_char(b.unsafe_to_char())
      n += 1
    }
  }
  let s = out.to_string()
  if starts_with_is && n == 1 && s == "c" {
    "isc"
  } else {
    s
  }
}

///|
fn canonical_prop(norm : String) -> String? {
  sorted_lookup(property_names_data, norm)
}

///|
fn property_values(canon_prop : String) -> Array[(String, String)]? {
  for entry in property_values_data {
    if entry.0 == canon_prop {
      return Some(entry.1)
    }
  }
  None
}

///|
fn canonical_value(vals : Array[(String, String)], norm : String) -> String? {
  sorted_lookup(vals, norm)
}

///|
fn canonical_gencat(norm : String) -> String? {
  match norm {
    "any" => Some("Any")
    "assigned" => Some("Assigned")
    "ascii" => Some("ASCII")
    _ => canonical_value(property_values("General_Category").unwrap(), norm)
  }
}

///|
fn canonical_script(norm : String) -> String? {
  canonical_value(property_values("Script").unwrap(), norm)
}

///|
/// A query for a Unicode class, e.g. `\pL`, `\p{Greek}` or `\p{sc=Greek}`.
pub(all) enum ClassQuery {
  OneLetter(Char)
  Binary(String)
  ByValue(String, String)
}

///|
priv enum Canonical {
  CBinary(String)
  CGeneralCategory(String)
  CScript(String)
  CByValue(String, String)
}

///|
fn canonical_binary(name : String) -> Canonical raise UnicodeError {
  let norm = symbolic_name_normalize(name)
  if norm != "cf" && norm != "sc" && norm != "lc" {
    if canonical_prop(norm) is Some(canon) {
      return CBinary(canon)
    }
  }
  if canonical_gencat(norm) is Some(canon) {
    return CGeneralCategory(canon)
  }
  if canonical_script(norm) is Some(canon) {
    return CScript(canon)
  }
  raise PropertyNotFound
}

///|
fn canonicalize(q : ClassQuery) -> Canonical raise UnicodeError {
  match q {
    OneLetter(c) => canonical_binary(c.to_string())
    Binary(name) => canonical_binary(name)
    ByValue(pname, pvalue) => {
      let pname = symbolic_name_normalize(pname)
      let pvalue = symbolic_name_normalize(pvalue)
      guard canonical_prop(pname) is Some(canon_name) else {
        raise PropertyNotFound
      }
      match canon_name {
        "General_Category" => {
          guard canonical_gencat(pvalue) is Some(c) else {
            raise PropertyValueNotFound
          }
          CGeneralCategory(c)
        }
        "Script" => {
          guard canonical_script(pvalue) is Some(c) else {
            raise PropertyValueNotFound
          }
          CScript(c)
        }
        _ => {
          guard property_values(canon_name) is Some(vals) else {
            raise PropertyValueNotFound
          }
          guard canonical_value(vals, pvalue) is Some(v) else {
            raise PropertyValueNotFound
          }
          CByValue(canon_name, v)
        }
      }
    }
  }
}

///|
fn table(
  data : Array[(String, String)],
  name : String,
  err : UnicodeError,
) -> Array[(Int32, Int32)] raise UnicodeError {
  match find_table(data, name) {
    Some(s) => decode_ranges(s)
    None => raise err
  }
}

///|
/// Negates a sorted, canonical list of ranges over the scalar values.
fn negate_ranges(ranges : Array[(Int32, Int32)]) -> Array[(Int32, Int32)] {
  let out = []
  let mut next = 0
  for r in ranges {
    if r.0 > next {
      let mut end = r.0 - 1
      if next <= 0xD7FF && end >= 0xD800 && end <= 0xDFFF {
        end = 0xD7FF
      }
      out.push((next, end))
    }
    next = r.1 + 1
    if next == 0xD800 {
      next = 0xE000
    }
  }
  if next <= 0x10FFFF {
    out.push((next, 0x10FFFF))
  }
  out
}

///|
fn gencat(name : String) -> Array[(Int32, Int32)] raise UnicodeError {
  match name {
    "Decimal_Number" => perl_digit()
    "ASCII" => [(0, 0x7F)]
    "Any" => [(0, 0xD7FF), (0xE000, 0x10FFFF)]
    "Assigned" => negate_ranges(gencat("Unassigned"))
    _ => table(gencat_data, name, PropertyValueNotFound)
  }
}

///|
fn ages(canonical_age : String) -> Array[(Int32, Int32)] raise UnicodeError {
  let order = [
    "V1_1", "V2_0", "V2_1", "V3_0", "V3_1", "V3_2", "V4_0", "V4_1", "V5_0", "V5_1",
    "V5_2", "V6_0", "V6_1", "V6_2", "V6_3", "V7_0", "V8_0", "V9_0", "V10_0", "V11_0",
    "V12_0", "V12_1", "V13_0", "V14_0", "V15_0", "V15_1", "V16_0",
  ]
  let out = []
  for age in order {
    for r in table(age_data, age, PropertyValueNotFound) {
      out.push(r)
    }
    if age == canonical_age {
      return out
    }
  }
  raise PropertyValueNotFound
}

///|
/// Looks up the ranges of scalar values for the given class query. The
/// returned ranges may be unsorted or overlapping; callers should
/// canonicalize them.
pub fn class(q : ClassQuery) -> Array[(Int32, Int32)] raise UnicodeError {
  match canonicalize(q) {
    CBinary(name) =>
      match name {
        "Decimal_Number" => perl_digit()
        "White_Space" => perl_space()
        _ => table(bool_data, name, PropertyNotFound)
      }
    CGeneralCategory(name) => gencat(name)
    CScript(name) => table(script_data, name, PropertyValueNotFound)
    CByValue("Age", v) => ages(v)
    CByValue("Script_Extensions", v) =>
      table(scx_data, v, PropertyValueNotFound)
    CByValue("Grapheme_Cluster_Break", v) =>
      table(gcb_data, v, PropertyValueNotFound)
    CByValue("Sentence_Break", v) => table(sb_data, v, PropertyValueNotFound)
    CByValue("Word_Break", v) => table(wb_data, v, PropertyValueNotFound)
    CByValue(_, _) => raise PropertyNotFound
  }
}

///|
let perl_word_cache : Ref[Array[(Int32, Int32)]?] = Ref(None)

///|
/// The ranges for Unicode-aware `\w`.
pub fn perl_word() -> Array[(Int32, Int32)] {
  match perl_word_cache.val {
    Some(r) => r
    None => {
      let r = decode_ranges(perl_word_data[0].1)
      perl_word_cache.val = Some(r)
      r
    }
  }
}

///|
/// The ranges for Unicode-aware `\d`.
pub fn perl_digit() -> Array[(Int32, Int32)] {
  decode_ranges(find_table(gencat_data, "Decimal_Number").unwrap())
}

///|
/// The ranges for Unicode-aware `\s`.
pub fn perl_space() -> Array[(Int32, Int32)] {
  decode_ranges(find_table(bool_data, "White_Space").unwrap())
}

///|
/// Returns true if and only if the given scalar value is a Unicode word
/// character.
pub fn is_word_character(c : Int32) -> Bool {
  if c < 0x80 {
    return (c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '_'
  }
  let table = perl_word()
  let mut lo = 0
  let mut hi = table.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (s, e) = table[mid]
    if c < s {
      hi = mid
    } else if c > e {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
let uppercase_cache : Ref[Array[(Int32, Int32)]?] = Ref(None)

///|
/// Returns true if the scalar value has the Unicode `Uppercase` property
/// (Rust's `char::is_uppercase`).
pub fn is_uppercase(c : Int32) -> Bool {
  if c < 0x80 {
    return c >= 'A' && c <= 'Z'
  }
  let table = match uppercase_cache.val {
    Some(t) => t
    None => {
      let t = decode_ranges(find_table(bool_data, "Uppercase").unwrap())
      uppercase_cache.val = Some(t)
      t
    }
  }
  let mut lo = 0
  let mut hi = table.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (s, e) = table[mid]
    if c < s {
      hi = mid
    } else if c > e {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}
