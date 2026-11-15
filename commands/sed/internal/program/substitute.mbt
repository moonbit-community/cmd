///|
fn expand(replacement : String, hit : @bytere.Hit) -> String raise {
  let result = StringBuilder()
  let mut i = 0
  while i < replacement.length() {
    let c = replacement[i]
    if c == '&' {
      result.write_string(hit.groups[0].unwrap_or(""))
    } else if c == '\\' && i + 1 < replacement.length() {
      i += 1
      let e = replacement[i]
      if e >= '1' && e <= '9' {
        let index = e.to_int() - 48
        guard index < hit.groups.length() else {
          fail("invalid replacement backreference")
        }
        result.write_string(hit.groups[index].unwrap_or(""))
      } else {
        result.write_char(
          if e == 'n' {
            '\n'
          } else if e == 't' {
            '\t'
          } else {
            e.to_int().unsafe_to_char()
          },
        )
      }
    } else {
      result.write_char(c.to_int().unsafe_to_char())
    }
    i += 1
  }
  result.to_string()
}

///|
pub fn substitute(
  re : @bytere.Pattern,
  text : String,
  replacement : String,
  global : Bool,
  occurrence : Int32,
) -> (String, Bool) raise {
  let result = StringBuilder()
  let mut search = 0
  let mut copied = 0
  let mut count = 0
  let mut changed = false
  let mut nonempty_end = -1
  while search <= text.length() {
    guard re.find(text, start=search) is Some(hit) else { break }
    if hit.start == hit.end && hit.start == nonempty_end {
      search = hit.end + 1
      continue
    }
    count += 1
    let replace = if occurrence == 0 {
      global || count == 1
    } else {
      count == occurrence || (global && count > occurrence)
    }
    if replace {
      result.write_string(text[copied:hit.start].to_owned())
      result.write_string(expand(replacement, hit))
      copied = hit.end
      changed = true
      if !global {
        break
      }
    }
    nonempty_end = if hit.end > hit.start { hit.end } else { -1 }
    search = if hit.end == hit.start { hit.end + 1 } else { hit.end }
  }
  if !changed {
    return (text, false)
  }
  result.write_string(text[copied:].to_owned())
  (result.to_string(), changed)
}
