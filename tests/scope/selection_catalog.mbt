///|
// This deliberately recognizes only the current literal contract table. It is
// not a MoonBit parser: escapes, expressions and unfamiliar syntax widen scope.
fn sel_catalog_tokens(text : String) -> Array[String]? {
  let chars = text.iter().collect()
  if chars.any(char => char.to_int() > 127) {
    return None
  }
  let result : Array[String] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] is (' ' | '\n' | '\r' | '\t') {
      index += 1
      continue
    }
    let start = index
    match chars[index] {
      '"' => {
        index += 1
        while index < chars.length() && chars[index] != '"' {
          if chars[index] == '\\' || chars[index].to_int() < 32 {
            return None
          }
          index += 1
        }
        if index == chars.length() {
          return None
        }
        index += 1
      }
      'a'..<='z' | 'A'..<='Z' | '_' | '0'..<='9' => {
        index += 1
        while index < chars.length() &&
              chars[index] is ('a'..<='z' | 'A'..<='Z' | '_' | '0'..<='9') {
          index += 1
        }
      }
      '[' | ']' | '(' | ')' | ',' | '=' => index += 1
      _ => return None
    }
    result.push(
      chars[start:index].to_owned().map(char => char.to_string()).join(""),
    )
  }
  Some(result)
}

///|
fn sel_catalog_take(
  tokens : Array[String],
  position : Ref[Int32],
  expected : String,
) -> Bool {
  if tokens.get(position.val) == Some(expected) {
    position.val += 1
    true
  } else {
    false
  }
}

///|
fn sel_catalog_literal(token : String) -> Bool {
  token.length() >= 2 && token.has_prefix("\"") && token.has_suffix("\"")
}

///|
fn sel_catalog_list(
  tokens : Array[String],
  position : Ref[Int32],
  allowed : Array[String],
  strings~ : Bool = false,
  numbers~ : Bool = false,
) -> Bool {
  if !sel_catalog_take(tokens, position, "[") {
    return false
  }
  if sel_catalog_take(tokens, position, "]") {
    return true
  }
  for ;; {
    guard tokens.get(position.val) is Some(token) else { return false }
    if !(if strings {
        sel_catalog_literal(token)
      } else if numbers {
        !token.is_empty() && token.iter().all(char => char is ('0'..<='9'))
      } else {
        allowed.contains(token)
      }) {
      return false
    }
    position.val += 1
    if sel_catalog_take(tokens, position, "]") {
      return true
    }
    if !sel_catalog_take(tokens, position, ",") {
      return false
    }
    if sel_catalog_take(tokens, position, "]") {
      return true
    }
  }
}

///|
fn sel_catalog_rows(text : String) -> (String, String, Map[String, String])? {
  let parts = text
    .split("pub fn command_catalog() -> Array[CommandContract] {")
    .collect()
  guard parts is [prefix, body] else { return None }
  guard body.to_owned().split_once("\n}\n") is Some((table, suffix)) else {
    return None
  }
  guard sel_catalog_tokens(table.to_owned()) is Some(tokens) else {
    return None
  }
  let position = Ref(0)
  let rows : Map[String, String] = Map([])
  if !sel_catalog_take(tokens, position, "[") {
    return None
  }
  while !sel_catalog_take(tokens, position, "]") {
    let start = position.val
    if !sel_catalog_take(tokens, position, "contract") ||
      !sel_catalog_take(tokens, position, "(") {
      return None
    }
    guard tokens.get(position.val) is Some(name) && sel_catalog_literal(name) else {
      return None
    }
    let name = name
      .strip_prefix("\"")
      .unwrap()
      .strip_suffix("\"")
      .unwrap()
      .to_owned()
    if name.is_empty() || rows.contains(name) {
      return None
    }
    position.val += 1
    if !sel_catalog_take(tokens, position, ",") {
      return None
    }
    for
      allowed in [
        ["Core", "Extended", "Restricted"],
        ["NoInput", "OptionalStdin", "FileOrStdin", "StructuredInput"],
        ["ByteStream", "LineStream", "StructuredOutput"],
      ] {
      guard tokens.get(position.val) is Some(token) && allowed.contains(token) else {
        return None
      }
      position.val += 1
      if !sel_catalog_take(tokens, position, ",") {
        return None
      }
    }
    if !sel_catalog_list(tokens, position, [
        "FileRead", "FileWrite", "ProcessSpawn", "Network", "PermissionMutation",
        "SymbolicLink", "ProcessGroupCancellation",
      ]) ||
      !sel_catalog_take(tokens, position, ",") ||
      !sel_catalog_list(tokens, position, [], strings=true) {
      return None
    }
    if sel_catalog_take(tokens, position, ",") &&
      tokens.get(position.val) == Some("exit_codes") {
      position.val += 1
      if !sel_catalog_take(tokens, position, "=") ||
        !sel_catalog_list(tokens, position, [], numbers=true) {
        return None
      }
      ignore(sel_catalog_take(tokens, position, ","))
    }
    if !sel_catalog_take(tokens, position, ")") {
      return None
    }
    rows[name] = tokens[start:position.val].to_owned().join("\u0000")
    if tokens.get(position.val) != Some("]") &&
      !sel_catalog_take(tokens, position, ",") {
      return None
    }
  }
  if position.val != tokens.length() {
    return None
  }
  Some((prefix.to_owned(), suffix.to_owned(), rows))
}

///|
fn sel_catalog_changes(
  base : TreeSnapshot,
  candidate : TreeSnapshot,
) -> Array[String]? {
  guard snapshot_file(base, "core/cli/catalog.mbt") is Some(old) &&
    snapshot_file(candidate, "core/cli/catalog.mbt") is Some(new) &&
    old.mode == "100644" &&
    new.mode == "100644" else {
    return None
  }
  let old_text = @utf8.decode(old.content) catch { _ => return None }
  let new_text = @utf8.decode(new.content) catch { _ => return None }
  guard sel_catalog_rows(old_text) is Some((old_prefix, old_suffix, old_rows)) &&
    sel_catalog_rows(new_text) is Some((new_prefix, new_suffix, new_rows)) &&
    old_prefix == new_prefix &&
    old_suffix == new_suffix else {
    return None
  }
  Some(
    sorted_strings(old_rows.keys().collect() + new_rows.keys().collect()).filter(name => {
        old_rows.get(name) != new_rows.get(name)
      },
    ),
  )
}
