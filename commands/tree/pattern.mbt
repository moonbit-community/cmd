///|
priv enum PatternToken {
  Literal(Byte)
  Any
  Star
  DoubleStar
  Class(Bool, Array[(Byte, Byte)])
  Invalid
} derive(Eq)

///|
priv struct TreePattern {
  alternatives : Array[Array[PatternToken]]
  invalid : Bool
}

///|
fn fold_byte(byte : Byte, ignore_case : Bool) -> Byte {
  if ignore_case && byte >= b'A' && byte <= b'Z' {
    (byte.to_int() + 32).to_byte()
  } else {
    byte
  }
}

///|
fn compile_pattern(value : String, ignore_case : Bool) -> TreePattern {
  let alternatives : Array[Array[PatternToken]] = []
  let parts = value.split("|").map(part => part.to_owned()).collect()
  if parts.length() > 1 && parts.any(part => part == "") {
    return { alternatives, invalid: true, }
  }
  for part in parts {
    let bytes = @utf8.encode(part)
    let tokens : Array[PatternToken] = []
    let mut index = 0
    while index < bytes.length() {
      let byte = bytes[index]
      index += 1
      match byte {
        b'*' =>
          if index < bytes.length() && bytes[index] == b'*' {
            tokens.push(DoubleStar)
            index += 1
          } else {
            tokens.push(Star)
          }
        b'?' => tokens.push(Any)
        b'\\' => {
          if index == bytes.length() {
            tokens.push(Invalid)
            break
          }
          tokens.push(Literal(fold_byte(bytes[index], ignore_case)))
          index += 1
        }
        b'[' => {
          let negate = index < bytes.length() && bytes[index] == b'^'
          if negate {
            index += 1
          }
          let ranges : Array[(Byte, Byte)] = []
          while index < bytes.length() && bytes[index] != b']' {
            if bytes[index] == b'\\' {
              index += 1
            }
            if index == bytes.length() {
              break
            }
            let first = fold_byte(bytes[index], ignore_case)
            index += 1
            let last = if index < bytes.length() && bytes[index] == b'-' {
              index += 1
              if index < bytes.length() && bytes[index] == b'\\' {
                index += 1
              }
              if index == bytes.length() {
                break
              }
              let last = fold_byte(bytes[index], ignore_case)
              index += 1
              last
            } else {
              first
            }
            ranges.push((first, last))
          }
          if index == bytes.length() {
            tokens.push(Invalid)
            break
          }
          index += 1
          tokens.push(Class(negate, ranges))
        }
        _ => tokens.push(Literal(fold_byte(byte, ignore_case)))
      }
    }
    alternatives.push(tokens)
  }
  { alternatives, invalid: false, }
}

///|
// The provider treats a reached malformed pattern (-1) as a positive match.
fn pattern_at(
  tokens : Array[PatternToken],
  name : Bytes,
  position : Int32,
  index : Int32,
  directory : Bool,
  cache : Array[Int32],
) -> Int32 {
  let slot = position * (name.length() + 1) + index
  if cache[slot] != 2 {
    return cache[slot]
  }
  let result = if position == tokens.length() {
    if index == name.length() {
      1
    } else {
      0
    }
  } else {
    match tokens[position] {
      Invalid => -1
      Literal(b'/') if position + 1 == tokens.length() && index == name.length() =>
        if directory {
          1
        } else {
          0
        }
      Literal(byte) =>
        if index < name.length() && byte == name[index] {
          pattern_at(tokens, name, position + 1, index + 1, directory, cache)
        } else {
          0
        }
      Any =>
        if index < name.length() {
          pattern_at(tokens, name, position + 1, index + 1, directory, cache)
        } else {
          0
        }
      Class(negate, ranges) =>
        if index == name.length() {
          0
        } else {
          let included = ranges.any(range => {
            name[index] >= range.0 && name[index] <= range.1
          })
          if included != negate {
            pattern_at(tokens, name, position + 1, index + 1, directory, cache)
          } else {
            0
          }
        }
      Star | DoubleStar => {
        let double = tokens[position] == DoubleStar
        if double && position + 1 == tokens.length() {
          1
        } else {
          let mut cursor = index
          let mut found = pattern_at(
            tokens,
            name,
            position + 1,
            cursor,
            directory,
            cache,
          )
          if double &&
            found == 0 &&
            position > 0 &&
            tokens[position - 1] == Literal(b'/') &&
            position + 2 < tokens.length() &&
            tokens[position + 1] == Literal(b'/') {
            found = pattern_at(
              tokens,
              name,
              position + 2,
              cursor,
              directory,
              cache,
            )
          }
          while found == 0 && cursor < name.length() {
            if !double && name[cursor] == b'/' {
              break
            }
            cursor += 1
            if double {
              while cursor < name.length() && name[cursor] != b'/' {
                cursor += 1
              }
            }
            found = pattern_at(
              tokens,
              name,
              position + 1,
              cursor,
              directory,
              cache,
            )
          }
          found
        }
      }
    }
  }
  cache[slot] = result
  result
}

///|
fn matches_any(
  patterns : Array[TreePattern],
  value : String,
  directory : Bool,
  ignore_case : Bool,
) -> Bool {
  let bytes = @utf8.encode(value)
  let name = Bytes::makei(bytes.length(), index => {
    fold_byte(bytes[index], ignore_case)
  })
  for pattern in patterns {
    if pattern.invalid {
      return true
    }
    for alternative in pattern.alternatives {
      let cache = Array::make(
        (alternative.length() + 1) * (name.length() + 1),
        2,
      )
      if pattern_at(alternative, name, 0, 0, directory, cache) != 0 {
        return true
      }
    }
  }
  false
}
