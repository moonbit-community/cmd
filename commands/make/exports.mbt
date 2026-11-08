///|
priv struct ExportPolicy {
  explicit : Map[String, Bool]
  defaults : Set[String]
  mut all : Bool
  mut target_all : Bool
}

///|
fn ExportPolicy::new(names : Array[String]) -> ExportPolicy {
  let explicit : Map[String, Bool] = Map([])
  for name in names {
    explicit[name] = true
  }
  { explicit, defaults: Set([]), all: false, target_all: false, }
}

///|
fn ExportPolicy::add(self : ExportPolicy, name : String) -> Unit {
  self.explicit[name] = true
}

///|
fn ExportPolicy::remove(self : ExportPolicy, name : String) -> Unit {
  self.explicit[name] = false
}

///|
fn default_export_name(name : String) -> Bool {
  let mut first = true
  for char in name {
    if !(char is ('A'..<='Z' | 'a'..<='z' | '_')) &&
      (first || !(char is ('0'..<='9'))) {
      return false
    }
    first = false
  }
  !first
}

///|
fn ExportPolicy::names(
  self : ExportPolicy,
  variables : Map[String, Variable],
) -> Array[String] {
  variables
  .keys()
  .filter(name => {
    match self.explicit.get(name) {
      Some(exporting) => exporting
      None =>
        self.all && !self.defaults.contains(name) && default_export_name(name)
    }
  })
  .collect()
}

///|
fn ExportPolicy::finish_reading(self : ExportPolicy) -> Unit {
  // GNU applies this target after reading all makefiles, so it does not change
  // the environment of an earlier parse-time shell expansion.
  if self.target_all {
    self.all = true
  }
}

///|
fn export_directive(line : String) -> (Bool, String)? {
  for (keyword, exporting) in [("export", true), ("unexport", false)] {
    if !line.has_prefix(keyword) {
      continue
    }
    let rest = line[keyword.length():]
    if !rest.is_empty() &&
      !(rest[0] is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
      continue
    }
    // GNU tries the complete variable definition before treating its first
    // token as a modifier. Nonblank whitespace may belong to that name.
    if parse_assignment(line) is Some(_) {
      return None
    }
    return Some((exporting, trim_make_space_start(rest.to_owned())))
  }
  None
}

///|
fn mark_export(database : Database, name : String, exporting : Bool) -> Unit {
  // Naming an undefined variable creates an empty simple variable. In
  // particular, a later ?= must see it as defined even when unexported.
  if !database.variables.contains(name) {
    database.variables[name] = { value: "", immediate: true, }
  }
  if exporting {
    database.exported.add(name)
  } else {
    database.exported.remove(name)
  }
}

///|
fn export_assignment(
  source : String,
  exporting : Bool,
) -> (String, String, String, Bool)? raise MakeError {
  let mut source = source
  let mut exporting = exporting
  let mut unsupported = None
  for ;; {
    if export_directive(source) is Some((next, remaining)) {
      exporting = next
      source = remaining
      continue
    }
    if make_function_name(source) is Some("override" | "private" as modifier) &&
      !(parse_assignment(source) is Some((name, _, _)) && name == modifier) {
      unsupported = Some(modifier)
      source = trim_make_space_start(source[modifier.length():].to_owned())
      continue
    }
    return match parse_assignment(source) {
      Some((name, operator, value)) => {
        if unsupported is Some(modifier) {
          raise MakeError(
            "assignment modifier '\{modifier}' is outside the supported make profile",
          )
        }
        Some((name, operator, value, exporting))
      }
      None => None
    }
  }
}
