///|
suberror MakeError {
  MakeError(String)
}

///|
struct Variable {
  value : String
  immediate : Bool
}

///|
struct Rule {
  target : String
  dependencies : Array[String]
  recipes : Array[String]
  mut phony : Bool
}

///|
struct Database {
  variables : Map[String, Variable]
  rules : Map[String, Rule]
  mut default_target : String?
}

///|
struct Settings {
  cwd : String
  silent : Bool
  dry_run : Bool
  always_make : Bool
}

///|
fn valid_variable_name(name : String) -> Bool {
  if name == "" {
    return false
  }
  for char in name {
    if char == ' ' || char == '\t' || char == ':' || char == '#' {
      return false
    }
  }
  true
}

///|
fn remove_comment(line : String) -> String {
  let output = StringBuilder()
  let mut escaped = false
  for char in line {
    if char == '#' && !escaped {
      break
    }
    if escaped && char != '#' {
      output.write_char('\\')
    }
    if char == '\\' {
      escaped = !escaped
    } else {
      output.write_char(char)
      escaped = false
    }
  }
  if escaped {
    output.write_char('\\')
  }
  output.to_string()
}

///|
fn split_words(value : String) -> Array[String] {
  let result : Array[String] = []
  let word = StringBuilder()
  for char in value {
    if char.is_whitespace() {
      if !word.is_empty() {
        result.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(char)
    }
  }
  if !word.is_empty() {
    result.push(word.to_string())
  }
  result
}

///|
fn lookup_variable(
  name : String,
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int,
) -> String raise MakeError {
  if automatic.get(name) is Some(value) {
    return value
  }
  match variables.get(name) {
    Some({ value, immediate: true }) => value
    Some({ value, immediate: false }) =>
      expand(value, variables, automatic, depth + 1)
    None => ""
  }
}

///|
fn expand(
  value : String,
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int,
) -> String raise MakeError {
  if depth > 64 {
    raise MakeError("variable expansion exceeds the recursion limit")
  }
  let chars : Array[Char] = value.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '$' {
      output.write_char(chars[index])
      index += 1
      continue
    }
    if index + 1 >= chars.length() {
      output.write_char('$')
      break
    }
    match chars[index + 1] {
      '$' => {
        output.write_char('$')
        index += 2
      }
      '(' | '{' as open => {
        let close = if open == '(' { ')' } else { '}' }
        let mut end = index + 2
        while end < chars.length() && chars[end] != close {
          end += 1
        }
        if end >= chars.length() {
          raise MakeError("unterminated variable reference")
        }
        let name = String::from_array(chars[index + 2:end]).trim().to_owned()
        output.write_string(lookup_variable(name, variables, automatic, depth))
        index = end + 1
      }
      char => {
        output.write_string(
          lookup_variable(char.to_string(), variables, automatic, depth),
        )
        index += 2
      }
    }
  }
  output.to_string()
}

///|
fn parse_assignment(line : String) -> (String, String, String)? {
  let operators = [":=", "?=", "+=", "="]
  for operator in operators {
    if line.split_once(operator) is Some((left, right)) {
      let name = left.trim().to_owned()
      if valid_variable_name(name) {
        return Some((name, operator, right.trim().to_owned()))
      }
    }
  }
  None
}

///|
fn assign_variable(
  variables : Map[String, Variable],
  name : String,
  operator : String,
  value : String,
) -> Unit raise MakeError {
  match operator {
    "?=" =>
      if !variables.contains(name) {
        variables[name] = { value, immediate: false }
      }
    ":=" =>
      variables[name] = {
        value: expand(value, variables, {}, 0),
        immediate: true,
      }
    "+=" =>
      match variables.get(name) {
        Some(previous) => {
          let separator = if previous.value == "" || value == "" {
            ""
          } else {
            " "
          }
          variables[name] = {
            value: previous.value + separator + value,
            immediate: previous.immediate,
          }
        }
        None => variables[name] = { value, immediate: false }
      }
    _ => variables[name] = { value, immediate: false }
  }
}

///|
fn logical_lines(contents : String) -> Array[String] raise MakeError {
  if contents.length() > 16 * 1024 * 1024 {
    raise MakeError("Makefile exceeds the 16 MiB safety limit")
  }
  let result : Array[String] = []
  let pending = StringBuilder()
  for raw_line in contents.split("\n") {
    let line = raw_line.to_owned()
    if line.has_prefix("\t") {
      if !pending.is_empty() {
        raise MakeError("recipe encountered during a continued logical line")
      }
      result.push(line)
    } else if line.has_suffix("\\") {
      pending.write_string(line[:line.length() - 1].to_owned())
      pending.write_char(' ')
    } else if pending.is_empty() {
      result.push(line)
    } else {
      pending.write_string(line)
      result.push(pending.to_string())
      pending.reset()
    }
  }
  if !pending.is_empty() {
    raise MakeError("Makefile ends with a continued line")
  }
  result
}

///|
fn parse_makefile(
  contents : String,
  database : Database,
) -> Unit raise MakeError {
  let mut current_rules : Array[Rule] = []
  for line_number, source_line in logical_lines(contents) {
    if source_line.has_prefix("\t") {
      if current_rules.is_empty() {
        raise MakeError("recipe without a target at line \{line_number + 1}")
      }
      let recipe = source_line[1:].to_owned()
      for rule in current_rules {
        rule.recipes.push(recipe)
      }
      continue
    }
    current_rules = []
    let line = remove_comment(source_line).trim().to_owned()
    if line == "" {
      continue
    }
    if line.has_prefix("include ") || line.has_prefix("-include ") {
      raise MakeError("include directives are not supported")
    }
    if parse_assignment(line) is Some((name, operator, value)) {
      assign_variable(database.variables, name, operator, value)
      continue
    }
    guard line.split_once(":") is Some((targets_text, deps_text)) else {
      raise MakeError(
        "expected a rule or assignment at line \{line_number + 1}",
      )
    }
    let targets = split_words(
      expand(targets_text.to_owned(), database.variables, {}, 0),
    )
    let dependencies = split_words(
      expand(deps_text.to_owned(), database.variables, {}, 0),
    )
    if targets.is_empty() {
      raise MakeError("rule has no target at line \{line_number + 1}")
    }
    if targets == [".PHONY"] {
      for target in dependencies {
        match database.rules.get(target) {
          Some(rule) => rule.phony = true
          None =>
            database.rules[target] = {
              target,
              dependencies: [],
              recipes: [],
              phony: true,
            }
        }
      }
      continue
    }
    for target in targets {
      let rule = match database.rules.get(target) {
        Some(existing) => {
          existing.dependencies.append(dependencies)
          existing
        }
        None => {
          let created : Rule = {
            target,
            dependencies: dependencies.copy(),
            recipes: [],
            phony: false,
          }
          database.rules[target] = created
          created
        }
      }
      if database.default_target is None && !target.has_prefix(".") {
        database.default_target = Some(target)
      }
      current_rules.push(rule)
    }
  }
}

///|
fn path_in(cwd : String, path : String) -> String {
  let parsed = @path.Path(path)
  if parsed.is_absolute() {
    parsed.normalize().to_string()
  } else {
    @path.Path(cwd).join(parsed).normalize().to_string()
  }
}

///|
async fn newer(left : String, right : String) -> Bool {
  let (left_s, left_ns) = @fs.mtime(left)
  let (right_s, right_ns) = @fs.mtime(right)
  left_s > right_s || (left_s == right_s && left_ns > right_ns)
}

///|
fn command_environment(database : Database) -> Map[String, String] raise {
  let result = @env.get_env_vars()
  for name, variable in database.variables {
    result[name] = if variable.immediate {
      variable.value
    } else {
      expand(variable.value, database.variables, Map([]), 0)
    }
  }
  result
}

///|
async fn run_recipe(
  recipe : String,
  rule : Rule,
  database : Database,
  settings : Settings,
) -> Int {
  let automatic : Map[String, String] = {
    "@": rule.target,
    "<": rule.dependencies.get(0).unwrap_or(""),
    "^": rule.dependencies.join(" "),
  }
  let mut command = expand(recipe, database.variables, automatic, 0)
  let mut local_silent = settings.silent
  let mut ignore_error = false
  let mut scanning = true
  while scanning && command != "" {
    match command[0] {
      '@' => {
        local_silent = true
        command = command[1:].to_owned()
      }
      '-' => {
        ignore_error = true
        command = command[1:].to_owned()
      }
      '+' => command = command[1:].to_owned()
      _ => scanning = false
    }
  }
  if !local_silent || settings.dry_run {
    @stdio.stdout.write(command + "\n")
  }
  if settings.dry_run || command.trim().is_empty() {
    return 0
  }
  let status = @shell.run(
    command,
    name="make",
    env=command_environment(database),
    cwd=settings.cwd,
  )
  if status != 0 && !ignore_error {
    status
  } else {
    0
  }
}

///|
async fn build_target(
  target : String,
  database : Database,
  settings : Settings,
  states : Map[String, Int],
) -> Unit {
  match states.get(target) {
    Some(1) => raise MakeError("dependency cycle detected at '\{target}'")
    Some(2) => return
    _ => states[target] = 1
  }
  let target_path = path_in(settings.cwd, target)
  let rule = match database.rules.get(target) {
    Some(value) => value
    None => {
      if @fs.exists(target_path) {
        states[target] = 2
        return
      }
      raise MakeError("no rule to make target '\{target}'")
    }
  }
  for dependency in rule.dependencies {
    build_target(dependency, database, settings, states)
  }
  let target_exists = if rule.phony { false } else { @fs.exists(target_path) }
  let mut rebuild = settings.always_make || rule.phony || !target_exists
  if !rebuild {
    for dependency in rule.dependencies {
      let dependency_path = path_in(settings.cwd, dependency)
      if @fs.exists(dependency_path) && newer(dependency_path, target_path) {
        rebuild = true
        break
      }
      if database.rules.get(dependency) is Some({ phony: true, .. }) {
        rebuild = true
        break
      }
    }
  }
  if rebuild {
    for recipe in rule.recipes {
      let status = run_recipe(recipe, rule, database, settings)
      if status != 0 {
        raise MakeError("recipe for '\{target}' failed with status \{status}")
      }
    }
  }
  states[target] = 2
}

///|
async fn choose_makefile(cwd : String, requested : String?) -> String {
  match requested {
    Some(path) => {
      let resolved = path_in(cwd, path)
      if !@fs.exists(resolved) {
        raise MakeError("Makefile not found: \{path}")
      }
      resolved
    }
    None => {
      for candidate in ["GNUmakefile", "makefile", "Makefile"] {
        let resolved = path_in(cwd, candidate)
        if @fs.exists(resolved) {
          return resolved
        }
      }
      raise MakeError("no Makefile found")
    }
  }
}

///|
async fn run(arguments : Array[String]) -> Unit {
  let mut requested_file : String? = None
  let mut cwd = @env.current_dir().unwrap_or(".")
  let mut silent = false
  let mut dry_run = false
  let mut always_make = false
  let mut options = true
  let targets : Array[String] = []
  let cli_assignments : Array[(String, String)] = []
  let mut index = 0
  while index < arguments.length() {
    let argument = arguments[index]
    if options && argument == "--" {
      options = false
    } else if options && (argument == "-f" || argument == "--file") {
      if index + 1 >= arguments.length() {
        raise MakeError("\{argument} requires a file")
      }
      index += 1
      requested_file = Some(arguments[index])
    } else if options && argument.has_prefix("--file=") {
      requested_file = Some(argument[7:].to_owned())
    } else if options && argument == "-C" {
      if index + 1 >= arguments.length() {
        raise MakeError("-C requires a directory")
      }
      index += 1
      cwd = path_in(cwd, arguments[index])
    } else if options && (argument == "-s" || argument == "--silent") {
      silent = true
    } else if options && (argument == "-n" || argument == "--just-print") {
      dry_run = true
    } else if options && (argument == "-B" || argument == "--always-make") {
      always_make = true
    } else if options && (argument == "-h" || argument == "--help") {
      @stdio.stdout.write(
        "Usage: make [-Bns] [-C DIR] [-f FILE] [VARIABLE=VALUE] [TARGET...]\n",
      )
      return
    } else if options && argument.has_prefix("-") && argument != "-" {
      raise MakeError("unsupported option '\{argument}'")
    } else {
      match parse_assignment(argument) {
        Some((name, _, value)) => cli_assignments.push((name, value))
        None => targets.push(argument)
      }
    }
    index += 1
  }
  let variables : Map[String, Variable] = Map([])
  for name, value in @env.get_env_vars() {
    variables[name] = { value, immediate: true }
  }
  let database : Database = { variables, rules: {}, default_target: None }
  let makefile = choose_makefile(cwd, requested_file)
  parse_makefile(@fs.read_file(makefile).text(), database)
  for assignment in cli_assignments {
    let (name, value) = assignment
    database.variables[name] = { value, immediate: true }
  }
  let requested_targets = if targets.is_empty() {
    match database.default_target {
      Some(value) => [value]
      None => raise MakeError("Makefile contains no targets")
    }
  } else {
    targets
  }
  let settings : Settings = { cwd, silent, dry_run, always_make }
  let states : Map[String, Int] = Map([])
  for target in requested_targets {
    build_target(target, database, settings, states)
  }
}

///|
async fn main {
  run(@env.args()[1:].to_owned()) catch {
    MakeError(message) => {
      @stdio.stderr.write("make: \{message}\n")
      @sys.exit(2)
    }
    err => {
      @stdio.stderr.write("make: \{err}\n")
      @sys.exit(2)
    }
  }
}
