///|
fn replace_stem(word : String, stem : String) -> String {
  match word.split_once("%") {
    Some((before, after)) => before.to_owned() + stem + after.to_owned()
    None => word
  }
}

///|
fn replace_stems(text : String, stem : String) -> String {
  let result = StringBuilder()
  let mut replaced = false
  for char in text {
    if char.is_whitespace() {
      replaced = false
      result.write_char(char)
    } else if char == '%' && !replaced {
      result.write_string(stem)
      replaced = true
    } else {
      result.write_char(char)
    }
  }
  result.to_string()
}

///|
priv struct Prerequisites {
  text : String
  secondary : Bool
  mut has_recipe : Bool
  stem : String?
}

///|
fn distinct_words(words : Array[String]) -> Array[String] {
  let seen = Set([])
  words.filter(word => {
    if seen.contains(word) {
      false
    } else {
      seen.add(word)
      true
    }
  })
}

///|
fn automatic_variables(
  target : String,
  stem : String?,
  dependencies : Array[String],
  newer_dependencies~ : Array[String] = [],
) -> Map[String, String] {
  let automatic : Map[String, String] = {
    "@": target,
    "<": dependencies.get(0).unwrap_or(""),
    "^": distinct_words(dependencies).join(" "),
    "+": dependencies.join(" "),
    "*": stem.unwrap_or(""),
    "?": distinct_words(newer_dependencies).join(" "),
    "%": "",
  }
  for name in ["@", "<", "^", "+", "*", "?"] {
    let words = split_words(automatic[name])
    automatic[name + "D"] = words
      .map(word => @path.Path(word).dirname().to_string())
      .join(" ")
    automatic[name + "F"] = words
      .map(word => @path.Path(word).basename().to_owned())
      .join(" ")
  }
  automatic
}

///|
async fn resolve_prerequisites(
  rule : Rule,
  database : Database,
) -> Array[String] {
  let groups = rule.groups
  // GNU make 4.4.1 prepends the recipe-bearing declaration to its dependency
  // chain. Concrete prerequisites are visible even before deferred entries.
  let expanded = groups.map(group => {
    if group.secondary {
      None
    } else {
      Some(split_words(group.text))
    }
  })
  for index, group in groups {
    if !group.secondary {
      continue
    }
    let known : Array[String] = []
    for words in expanded {
      if words is Some(words) {
        known.append(words)
      }
    }
    let stem = match group.stem {
      Some(_) => group.stem
      None => rule.stem
    }
    expanded[index] = Some(
      split_words(
        expand(
          group.text,
          database.variables,
          automatic_variables(rule.target, stem, known),
          0,
          cwd=database.cwd,
          exported=database.exported,
          state=database.expansion(),
        ),
      ),
    )
  }
  let result : Array[String] = []
  for words in expanded {
    if words is Some(words) {
      result.append(words)
    }
  }
  validate_rule_words([rule.target], result)
  result
}
