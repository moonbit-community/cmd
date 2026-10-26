///|
priv enum CapRef {
  Named(String)
  Number(Int32)
}

///|
fn is_valid_cap_letter(b : Byte) -> Bool {
  match b {
    b'0'..<=b'9' | b'a'..<=b'z' | b'A'..<=b'Z' | b'_' => true
    _ => false
  }
}

///|
/// Parses a capture reference at the start of `rep[i:]` (which must start
/// with `$`), returning the reference and the index just past it.
fn find_cap_ref(rep : Bytes, i : Int32) -> (CapRef, Int32)? {
  let n = rep.length()
  if n - i <= 1 || rep[i] != b'$' {
    return None
  }
  let mut j = i + 1
  let mut brace = false
  if rep[j] == b'{' {
    brace = true
    j += 1
  }
  let mut cap_end = j
  while cap_end < n && is_valid_cap_letter(rep[cap_end]) {
    cap_end += 1
  }
  if cap_end == j {
    return None
  }
  let name_buf = StringBuilder()
  for k in j..<cap_end {
    name_buf.write_char(rep[k].to_int().unsafe_to_char())
  }
  let name = name_buf.to_string()
  if brace {
    if !(cap_end < n && rep[cap_end] == b'}') {
      return None
    }
    cap_end += 1
  }
  let mut is_num = true
  let mut num = 0
  for c in name {
    if c >= '0' && c <= '9' {
      let d = c.to_int() - '0'.to_int()
      if num > (0x7FFFFFFF - d) / 10 {
        is_num = false
        break
      }
      num = num * 10 + d
    } else {
      is_num = false
      break
    }
  }
  if is_num {
    Some((Number(num), cap_end))
  } else {
    Some((Named(name), cap_end))
  }
}

///|
/// Interpolates capture references in `replacement` into `dst`. `append`
/// is called with a group index to write that group's text; `name_to_index`
/// resolves named groups.
pub fn interpolate(
  replacement : Bytes,
  append : (Int32, Buffer) -> Unit,
  name_to_index : (String) -> Int32?,
  dst : Buffer,
) -> Unit {
  let n = replacement.length()
  let mut i = 0
  while i < n {
    // Find the next '$'.
    let mut j = i
    while j < n && replacement[j] != b'$' {
      j += 1
    }
    if j == n {
      break
    }
    for k in i..<j {
      dst.write_byte(replacement[k])
    }
    i = j
    if i + 1 < n && replacement[i + 1] == b'$' {
      dst.write_byte(b'$')
      i += 2
      continue
    }
    match find_cap_ref(replacement, i) {
      None => {
        dst.write_byte(b'$')
        i += 1
      }
      Some((cap, end)) => {
        i = end
        match cap {
          Number(k) => append(k, dst)
          Named(name) => if name_to_index(name) is Some(k) { append(k, dst) }
        }
      }
    }
  }
  for k in i..<n {
    dst.write_byte(replacement[k])
  }
}
