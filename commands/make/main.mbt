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
  mut stem : String?
}

///|
struct Database {
  cwd : String
  variables : Map[String, Variable]
  command_line_variables : Map[String, Bool]
  exported : Set[String]
  rules : Map[String, Rule]
  mut default_target : String?
}

///|
struct Settings {
  jobs : Int
  cwd : String
  silent : Bool
  dry_run : Bool
  always_make : Bool
  keep_going : Bool
  what_if : Map[String, Bool]
}

///|
async fn conditional_value(line : String, database : Database) -> Bool {
  if line.has_prefix("ifdef ") {
    let name = line[6:].trim().to_owned()
    let value = lookup_variable(
      name,
      database.variables,
      {},
      0,
      cwd=database.cwd,
      exported=database.exported,
    )
    value != ""
  } else if line.has_prefix("ifndef ") {
    let name = line[7:].trim().to_owned()
    let value = lookup_variable(
      name,
      database.variables,
      {},
      0,
      cwd=database.cwd,
      exported=database.exported,
    )
    value == ""
  } else {
    let negated = line.has_prefix("ifneq ")
    let prefix = if negated { "ifneq " } else { "ifeq " }
    if !line.has_prefix(prefix) {
      false
    } else {
      let rest = line[prefix.length():].trim()
      let rest = if rest.has_prefix("(") && rest.has_suffix(")") {
        rest[1:rest.length() - 1].to_owned()
      } else {
        rest.to_owned()
      }
      let parts : Array[String] = rest
        .split(",")
        .map(x => x.trim().to_owned())
        .collect()
      let equal = if parts.length() == 2 {
        let left = expand(
          parts[0],
          database.variables,
          {},
          0,
          cwd=database.cwd,
          exported=database.exported,
        )
        let right = expand(
          parts[1],
          database.variables,
          {},
          0,
          cwd=database.cwd,
          exported=database.exported,
        )
        left == right
      } else {
        false
      }
      if negated {
        !equal
      } else {
        equal
      }
    }
  }
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
async fn lookup_variable(
  name : String,
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int,
  cwd? : String = @env.current_dir().unwrap_or("."),
  exported? : Set[String] = Set([]),
) -> String {
  if automatic.get(name) is Some(value) {
    return value
  }
  match variables.get(name) {
    Some({ value, immediate: true, }) => value
    Some({ value, immediate: false, }) =>
      expand(value, variables, automatic, depth + 1, cwd~, exported~)
    None => ""
  }
}

///|
async fn expand(
  value : String,
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int,
  cwd? : String = @env.current_dir().unwrap_or("."),
  exported? : Set[String] = Set([]),
) -> String {
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
        let mut nesting = 1
        while end < chars.length() {
          if chars[end] == open {
            nesting += 1
          }
          if chars[end] == close {
            nesting -= 1
            if nesting == 0 {
              break
            }
          }
          end += 1
        }
        if end >= chars.length() {
          raise MakeError("unterminated variable reference")
        }
        let name = String::from_array(chars[index + 2:end]).trim().to_owned()
        if name.has_prefix("shell ") || name.has_prefix("shell\t") {
          let script = expand(
            name[6:].to_owned(),
            variables,
            automatic,
            depth + 1,
            cwd~,
            exported~,
          )
          let shell_environment : Map[String, String] = Map([])
          for name in exported {
            if variables.get(name) is Some(variable) {
              if variable.value.contains("$(shell") ||
                variable.value.contains("${shell") {
                raise MakeError(
                  "recursive shell-function exports are not supported",
                )
              }
              shell_environment[name] = lookup_variable(
                name,
                variables,
                automatic,
                depth + 1,
                cwd~,
                exported~,
              )
            }
          }
          let (status, result) = @shell.capture(
            script,
            name="make",
            cwd~,
            env=shell_environment,
          )
          variables[".SHELLSTATUS"] = {
            value: status.to_string(),
            immediate: true,
          }
          // GNU make removes trailing newlines and folds each embedded newline
          // into a space. Spaces within a line remain significant.
          let chars = result.replace(old="\r\n", new="\n")
          let mut length = chars.length()
          while length > 0 && chars[length - 1] == '\n' {
            length -= 1
          }
          output.write_string(
            chars[:length].to_owned().replace(old="\n", new=" "),
          )
        } else {
          let variable = expand(
            name,
            variables,
            automatic,
            depth + 1,
            cwd~,
            exported~,
          )
          output.write_string(
            lookup_variable(
              variable,
              variables,
              automatic,
              depth,
              cwd~,
              exported~,
            ),
          )
        }
        index = end + 1
      }
      char => {
        if index + 2 < chars.length() &&
          chars[index + 1] is ('@' | '<') &&
          chars[index + 2] is ('D' | 'F') {
          let name = String::from_array(chars[index + 1:index + 3])
          output.write_string(
            lookup_variable(name, variables, automatic, depth, cwd~, exported~),
          )
          index += 3
          continue
        }
        output.write_string(
          lookup_variable(
            char.to_string(),
            variables,
            automatic,
            depth,
            cwd~,
            exported~,
          ),
        )
        index += 2
      }
    }
  }
  output.to_string()
}

///|
fn pattern_match(pattern : String, target : String) -> String? {
  guard pattern.split_once("%") is Some((prefix, suffix)) else { return None }
  if target.has_prefix(prefix) &&
    target.has_suffix(suffix) &&
    target.length() >= prefix.length() + suffix.length() {
    Some(target[prefix.length():target.length() - suffix.length()].to_owned())
  } else {
    None
  }
}

///|
fn instantiate_pattern(rule : Rule, target : String) -> Rule? {
  guard rule.target.contains("%") else { return None }
  guard pattern_match(rule.target, target) is Some(stem) else { return None }
  Some({
    target,
    dependencies: rule.dependencies.map(dep => {
      dep.replace_all(old="%", new=stem)
    }),
    recipes: rule.recipes.copy(),
    phony: rule.phony,
    stem: Some(stem),
  })
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
async fn assign_variable(
  database : Database,
  name : String,
  operator : String,
  value : String,
) -> Unit {
  if database.command_line_variables.contains(name) {
    return
  }
  let variables = database.variables
  match operator {
    "?=" =>
      if !variables.contains(name) {
        variables[name] = { value, immediate: false, }
      }
    ":=" =>
      variables[name] = {
        value: expand(
          value,
          variables,
          {},
          0,
          cwd=database.cwd,
          exported=database.exported,
        ),
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
            value: previous.value +
            separator +
            (if previous.immediate {
              expand(
                value,
                variables,
                {},
                0,
                cwd=database.cwd,
                exported=database.exported,
              )
            } else {
              value
            }),
            immediate: previous.immediate,
          }
        }
        None => variables[name] = { value, immediate: false, }
      }
    _ => variables[name] = { value, immediate: false, }
  }
}

///|
fn logical_lines(contents : String) -> Array[String] raise MakeError {
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
async fn parse_makefile(
  contents : String,
  database : Database,
  source_directory : String,
  depth : Int,
) -> Unit {
  if depth > 64 {
    raise MakeError("include nesting exceeds the recursion limit")
  }
  let mut current_rules : Array[Rule] = []
  let active : Array[Bool] = [true]
  for line_number, source_line in logical_lines(contents) {
    let directive = remove_comment(source_line).trim().to_owned()
    if directive.has_prefix("ifeq ") ||
      directive.has_prefix("ifneq ") ||
      directive.has_prefix("ifdef ") ||
      directive.has_prefix("ifndef ") {
      active.push(
        active.last().unwrap_or(false) && conditional_value(directive, database),
      )
      current_rules = []
      continue
    }
    if directive == "else" {
      if active.length() <= 1 {
        raise MakeError("unexpected else")
      }
      let previous = active.pop().unwrap()
      active.push(active.last().unwrap_or(false) && !previous)
      current_rules = []
      continue
    }
    if directive == "endif" {
      if active.length() <= 1 {
        raise MakeError("unexpected endif")
      }
      ignore(active.pop())
      current_rules = []
      continue
    }
    if !active.last().unwrap_or(false) {
      continue
    }
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
    if line.has_prefix("include ") ||
      line.has_prefix("-include ") ||
      line.has_prefix("sinclude ") {
      let optional = line.has_prefix("-include ") ||
        line.has_prefix("sinclude ")
      let names = if line.has_prefix("-include ") {
        line[9:].to_owned()
      } else if line.has_prefix("sinclude ") {
        line[9:].to_owned()
      } else {
        line[8:].to_owned()
      }
      let expanded = expand(
        names,
        database.variables,
        {},
        0,
        cwd=database.cwd,
        exported=database.exported,
      )
      for name in split_words(expanded) {
        let included = path_in(source_directory, name)
        if @fs.exists(included) {
          parse_makefile(
            @fs.read_file(included).text(),
            database,
            @path.Path(included).dirname().to_string(),
            depth + 1,
          )
        } else if !optional {
          raise MakeError("included makefile not found: \{name}")
        }
      }
      continue
    }
    if line.has_prefix("export ") || line.has_prefix("unexport ") {
      let exporting = line.has_prefix("export ")
      let contents = line[if exporting { 7 } else { 9 }:].trim().to_owned()
      match parse_assignment(contents) {
        Some((name, operator, value)) if exporting => {
          assign_variable(database, name, operator, value)
          database.exported.add(name)
        }
        _ =>
          for name in split_words(contents) {
            if exporting {
              database.exported.add(name)
            } else {
              database.exported.remove(name)
            }
          }
      }
      continue
    }
    if line == "export" || line == "unexport" {
      raise MakeError("bare export/unexport directives are not supported")
    }
    if parse_assignment(line) is Some((name, operator, value)) {
      assign_variable(database, name, operator, value)
      continue
    }
    guard line.split_once(":") is Some((targets_text, deps_text)) else {
      raise MakeError(
        "expected a rule or assignment at line \{line_number + 1}",
      )
    }
    let static_pattern = deps_text.split_once(":")
    let prerequisite_text = match static_pattern {
      Some((pattern, prerequisites)) if pattern.trim().contains("%") =>
        prerequisites.to_owned()
      _ => deps_text.to_owned()
    }
    let targets = split_words(
      expand(
        targets_text.to_owned(),
        database.variables,
        {},
        0,
        cwd=database.cwd,
        exported=database.exported,
      ),
    )
    let dependencies = split_words(
      expand(
        prerequisite_text,
        database.variables,
        {},
        0,
        cwd=database.cwd,
        exported=database.exported,
      ),
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
              stem: None,
            }
        }
      }
      continue
    }
    for target in targets {
      let (dependencies, stem) = match static_pattern {
        Some((pattern, _)) if pattern.trim().contains("%") => {
          let pattern = pattern.trim().to_owned()
          match pattern_match(pattern, target) {
            Some(stem) =>
              (
                dependencies.map(dep => dep.replace_all(old="%", new=stem)),
                Some(stem),
              )
            None => (dependencies.copy(), None)
          }
        }
        _ => (dependencies.copy(), None)
      }
      let rule = match database.rules.get(target) {
        Some(existing) => {
          existing.dependencies.append(dependencies)
          if stem is Some(value) {
            existing.stem = Some(value)
          }
          existing
        }
        None => {
          let created : Rule = {
            target,
            dependencies: dependencies.copy(),
            recipes: [],
            phony: false,
            stem,
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
  if active.length() != 1 {
    raise MakeError("missing endif")
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
async fn command_environment(database : Database) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  for name in database.exported {
    if database.variables.get(name) is Some(variable) {
      result[name] = if variable.immediate {
        variable.value
      } else {
        expand(
          variable.value,
          database.variables,
          Map([]),
          0,
          cwd=database.cwd,
          exported=database.exported,
        )
      }
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
    "+": rule.dependencies.join(" "),
    "*": rule.stem.unwrap_or(""),
  }
  automatic["@D"] = @path.Path(rule.target).dirname().to_string()
  automatic["@F"] = @path.Path(rule.target).basename().to_owned()
  let first = rule.dependencies.get(0).unwrap_or("")
  automatic["<D"] = @path.Path(first).dirname().to_string()
  automatic["<F"] = @path.Path(first).basename().to_owned()
  let mut command = expand(
    recipe,
    database.variables,
    automatic,
    0,
    cwd=settings.cwd,
    exported=database.exported,
  )
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
fn positive_job_count(value : String) -> Bool {
  let count = @string.parse_int(value) catch { _ => return false }
  count > 0
}

///|
async fn run(arguments : Array[String]) -> Unit {
  let mut requested_file : String? = None
  let mut cwd = @env.current_dir().unwrap_or(".")
  let mut silent = false
  let mut dry_run = false
  let mut always_make = false
  let mut keep_going = false
  let mut jobs = 1
  let touch_targets : Map[String, Bool] = Map([])
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
    } else if options && (argument == "-k" || argument == "--keep-going") {
      keep_going = true
    } else if options && (argument == "-W" || argument == "--what-if") {
      if index + 1 >= arguments.length() {
        raise MakeError("\{argument} requires a file")
      }
      index += 1
      touch_targets[arguments[index]] = true
    } else if options && argument.has_prefix("--what-if=") {
      let value = argument[10:].to_owned()
      if value == "" {
        raise MakeError("--what-if requires a file")
      }
      touch_targets[value] = true
    } else if options && argument.has_prefix("-W") && argument.length() > 2 {
      touch_targets[argument[2:].to_owned()] = true
    } else if options && (argument == "-j" || argument == "--jobs") {
      jobs = 0
      if index + 1 < arguments.length() &&
        positive_job_count(arguments[index + 1]) {
        index += 1
        jobs = @string.parse_int(arguments[index])
      }
    } else if options && argument.has_prefix("--jobs=") {
      let value = argument[7:].to_owned()
      if !positive_job_count(value) {
        raise MakeError("the '-j' option requires a positive integer")
      }
      jobs = @string.parse_int(value)
    } else if options && argument.has_prefix("-j") && argument.length() > 2 {
      if !positive_job_count(argument[2:].to_owned()) {
        raise MakeError("the '-j' option requires a positive integer")
      }
      jobs = @string.parse_int(argument[2:])
    } else if options && (argument == "-h" || argument == "--help") {
      @stdio.stdout.write(
        "Usage: make [-Bkns] [-j [N]] [-W FILE] [-C DIR] [-f FILE] [VARIABLE=VALUE] [TARGET...]\n",
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
  for name, value in @process.default_environment() {
    variables[name] = { value, immediate: true, }
  }
  let command_line_variables : Map[String, Bool] = Map([])
  for assignment in cli_assignments {
    let (name, value) = assignment
    variables[name] = { value, immediate: true, }
    command_line_variables[name] = true
  }
  let database : Database = {
    cwd,
    variables,
    command_line_variables,
    exported: Set(variables.keys().collect()),
    rules: {},
    default_target: None,
  }
  let makefile = choose_makefile(cwd, requested_file)
  parse_makefile(
    @fs.read_file(makefile).text(),
    database,
    @path.Path(makefile).dirname().to_string(),
    0,
  )
  let requested_targets = if targets.is_empty() {
    match database.default_target {
      Some(value) => [value]
      None => raise MakeError("Makefile contains no targets")
    }
  } else {
    targets
  }
  let settings : Settings = {
    jobs,
    cwd,
    silent,
    dry_run,
    always_make,
    keep_going,
    what_if: touch_targets,
  }
  build_targets(requested_targets, database, settings)
}

///|
async fn main {
  run(@env.args()[1:].to_owned()) catch {
    MakeError(message) => {
      if message == "unexpected endif" {
        @stdio.stderr.write("Makefile:1: *** extraneous 'endif'.  Stop.\n")
      } else {
        @stdio.stderr.write("make: \{message}\n")
      }
      @sys.exit(2)
    }
    err => {
      @stdio.stderr.write("make: \{err}\n")
      @sys.exit(2)
    }
  }
}
