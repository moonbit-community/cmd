///|
priv struct Expansion {
  original : Map[String, String]
  active : Set[String]
  mut environment_depth : Int32
  level : Int32
  serial_children : Bool
}

///|
fn Expansion::new(
  original~ : Map[String, String] = @process.default_environment(),
  level~ : Int32 = 0,
  serial_children~ : Bool = false,
) -> Expansion {
  { original, active: Set([]), environment_depth: 0, level, serial_children, }
}

///|
fn Database::expansion(self : Database) -> Expansion {
  Expansion::new(
    level=self.invocation_level,
    serial_children=self.serial_children,
  )
}

///|
async fn expansion_environment(
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int32,
  cwd : String,
  exported : ExportPolicy,
  state : Expansion,
) -> Map[String, String] {
  state.environment_depth += 1
  defer {
    state.environment_depth -= 1
  }
  let result : Map[String, String] = Map([])
  if state.original.get("SHELL") is Some(shell) {
    result["SHELL"] = shell
  }
  for name in exported.names(variables) {
    if variables.contains(name) {
      result[name] = lookup_variable(
        name,
        variables,
        automatic,
        depth + 1,
        cwd~,
        exported~,
        state~,
      )
    }
  }
  result["MAKELEVEL"] = (state.level + 1).to_string()
  if state.serial_children && result.get("MAKEFLAGS") is Some(flags) {
    result["MAKEFLAGS"] = serial_child_flags(flags)
  }
  if result.get("MAKEFLAGS") is Some(flags) {
    result["MAKEFLAGS"] = flags.replace_all(old="$", new="$$")
  }
  result
}

///|
fn makelevel(variables : Map[String, Variable]) -> Int32 {
  let raw = variables
    .get("MAKELEVEL")
    .map(variable => variable.value)
    .unwrap_or("0")
  if raw.is_empty() || raw.iter().any(char => char < '0' || char > '9') {
    return 0
  }
  let value = @string.parse_int(raw, base=10) catch { _ => return 0 }
  if value == 2147483647 {
    0
  } else {
    value
  }
}

///|
async fn shell_result(
  script : String,
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int32,
  cwd : String,
  exported : ExportPolicy,
  state : Expansion,
  trim_newlines~ : Bool,
) -> String {
  // GNU expands the selectors even when argv construction finds no command.
  let shell = lookup_variable(
    "SHELL",
    variables,
    automatic,
    depth,
    cwd~,
    exported~,
    state~,
  )
  let flags = lookup_variable(
    ".SHELLFLAGS",
    variables,
    automatic,
    depth,
    cwd~,
    exported~,
    state~,
  )
  let ifs = lookup_variable(
    "IFS",
    variables,
    automatic,
    depth,
    cwd~,
    exported~,
    state~,
  )
  guard make_shell_source(
      script,
      ifs,
      force_shell=(shell != "" && !default_shell_profile(shell)) ||
        (flags != "" && flags != "-c"),
    )
    is Some(script) else {
    return ""
  }
  let environment = expansion_environment(
    variables, automatic, depth, cwd, exported, state,
  )
  let (status, result) = if script == "" {
    @stdio.stderr.write("sh: -c requires an argument\n")
    (2, "")
  } else {
    capture_shell(script, environment, cwd)
  }
  variables[".SHELLSTATUS"] = { value: status.to_string(), immediate: true, }
  let normalized = result.replace_all(old="\r\n", new="\n")
  let mut length = normalized.length()
  if trim_newlines {
    while length > 0 && normalized[length - 1] == '\n' {
      length -= 1
    }
  } else if length > 0 && normalized[length - 1] == '\n' {
    length -= 1
  }
  normalized[:length].to_owned().replace_all(old="\n", new=" ")
}
