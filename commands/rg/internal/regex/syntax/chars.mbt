///|
fn in_ranges(ranges : Array[(Int32, Int32)], c : Int32) -> Bool {
  let mut lo = 0
  let mut hi = ranges.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (s, e) = ranges[mid]
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
let white_space_table : Ref[Array[(Int32, Int32)]?] = Ref(None)

///|
let alphabetic_table : Ref[Array[(Int32, Int32)]?] = Ref(None)

///|
let numeric_table : Ref[Array[(Int32, Int32)]?] = Ref(None)

///|
fn cached_table(
  cell : Ref[Array[(Int32, Int32)]?],
  load : () -> Array[(Int32, Int32)],
) -> Array[(Int32, Int32)] {
  match cell.val {
    Some(t) => t
    None => {
      let t = canonicalize_ranges(load(), unicode=true)
      cell.val = Some(t)
      t
    }
  }
}

///|
/// Rust's `char::is_whitespace`.
pub fn is_whitespace_char(c : Char) -> Bool {
  let code = c.to_int()
  if code < 0x80 {
    return code == 0x20 || (code >= 0x09 && code <= 0x0D)
  }
  in_ranges(cached_table(white_space_table, @unicode.perl_space), code)
}

///|
/// Rust's `char::is_alphabetic`.
fn is_alphabetic_char(c : Char) -> Bool {
  let code = c.to_int()
  if code < 0x80 {
    return (code >= 'a' && code <= 'z') || (code >= 'A' && code <= 'Z')
  }
  in_ranges(
    cached_table(alphabetic_table, () => {
      try! @unicode.class(Binary("Alphabetic"))
    }),
    code,
  )
}

///|
/// Rust's `char::is_alphanumeric`.
fn is_alphanumeric_char(c : Char) -> Bool {
  if is_alphabetic_char(c) {
    return true
  }
  let code = c.to_int()
  if code < 0x80 {
    return code >= '0' && code <= '9'
  }
  in_ranges(
    cached_table(numeric_table, () => try! @unicode.class(OneLetter('N'))),
    code,
  )
}
