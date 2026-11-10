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
  groups : Array[Prerequisites]
  recipes : Array[String]
  mut phony : Bool
  mut stem : String?
}

///|
struct Database {
  cwd : String
  variables : Map[String, Variable]
  command_line_variables : Map[String, Bool]
  exported : ExportPolicy
  rules : Map[String, Rule]
  mut default_target : String?
  mut secondary_expansion : Bool
  mut invocation_level : Int32
  mut serial_children : Bool
}

///|
struct Settings {
  jobs : Int32
  jobserver : Jobserver?
  expansion_lock : @async.Mutex
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
      state=database.expansion(),
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
      state=database.expansion(),
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
          state=database.expansion(),
        )
        let right = expand(
          parts[1],
          database.variables,
          {},
          0,
          cwd=database.cwd,
          exported=database.exported,
          state=database.expansion(),
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
  depth : Int32,
  cwd~ : String = @env.current_dir().unwrap_or("."),
  exported~ : ExportPolicy = ExportPolicy::new([]),
  state~ : Expansion = Expansion::new(),
) -> String {
  if automatic.get(name) is Some(value) {
    return value
  }
  match variables.get(name) {
    Some({ value, immediate: true, }) => value
    Some({ value, immediate: false, }) => {
      if state.active.contains(name) {
        if state.environment_depth > 0 {
          return state.original.get(name).unwrap_or("")
        }
        raise MakeError("recursive variable '\{name}' references itself")
      }
      state.active.add(name)
      defer state.active.remove(name)
      expand(value, variables, automatic, depth + 1, cwd~, exported~, state~)
    }
    None => ""
  }
}

///|
async fn expand(
  value : String,
  variables : Map[String, Variable],
  automatic : Map[String, String],
  depth : Int32,
  cwd~ : String = @env.current_dir().unwrap_or("."),
  exported~ : ExportPolicy = ExportPolicy::new([]),
  state~ : Expansion = Expansion::new(),
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
        let name = String::from_array(chars[index + 2:end])
        reject_unsupported_function(name)
        if make_function_name(name) == Some("shell") {
          let script = expand(
            name[6:].to_owned(),
            variables,
            automatic,
            depth + 1,
            cwd~,
            exported~,
            state~,
          )
          output.write_string(
            shell_result(
              script,
              variables,
              automatic,
              depth,
              cwd,
              exported,
              state,
              trim_newlines=true,
            ),
          )
        } else {
          let variable = expand(
            name,
            variables,
            automatic,
            depth + 1,
            cwd~,
            exported~,
            state~,
          )
          if variable.contains(":") && variable.contains("=") {
            raise MakeError(
              "substitution references are outside the supported make profile",
            )
          }
          output.write_string(
            lookup_variable(
              variable,
              variables,
              automatic,
              depth,
              cwd~,
              exported~,
              state~,
            ),
          )
        }
        index = end + 1
      }
      char => {
        output.write_string(
          lookup_variable(
            char.to_string(),
            variables,
            automatic,
            depth,
            cwd~,
            exported~,
            state~,
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
    dependencies: rule.dependencies.map(dep => replace_stem(dep, stem)),
    groups: rule.groups.map(group => {
      ..group,
      text: replace_stems(group.text, stem),
    }),
    recipes: rule.recipes.copy(),
    phony: rule.phony,
    stem: Some(stem),
  })
}

///|
fn trim_make_space_start(text : String) -> String {
  let mut start = 0
  while start < text.length() &&
        text[start] is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c') {
    start += 1
  }
  text[start:].to_owned()
}

///|
fn parse_assignment(line : String) -> (String, String, String)? {
  guard split_rule_separator(line, '=') is Some((left, right)) else {
    return None
  }
  let mut left = left
  let mut operator = "="
  for prefix in [":::", "::", ":", "!", "?", "+"] {
    if left.has_suffix(prefix) {
      left = left[:left.length() - prefix.length()].to_owned()
      operator = prefix + "="
      break
    }
  }
  let mut start = 0
  let mut end = left.length()
  while start < end && left[start] is (' ' | '\t') {
    start += 1
  }
  while end > start && left[end - 1] is (' ' | '\t') {
    end -= 1
  }
  let name = left[start:end].to_owned()
  // An assignment operator may contain colons; after removing it, any outer
  // colon belongs to a rule. Its recipe must not become a computed LHS.
  if split_rule_separator(name, ':') is Some(_) ||
    split_rule_separator(name, ' ') is Some(_) ||
    split_rule_separator(name, '\t') is Some(_) {
    return None
  }
  if valid_variable_name(name) || name.contains("$(") || name.contains("${") {
    Some((name, operator, trim_make_space_start(right)))
  } else {
    None
  }
}

///|
async fn assign_variable(
  database : Database,
  name : String,
  operator : String,
  value : String,
) -> Unit {
  let state = database.expansion()
  let name = expand(
    name,
    database.variables,
    {},
    0,
    cwd=database.cwd,
    exported=database.exported,
    state~,
  )
  assign_resolved_variable(database, name, operator, value)
}

///|
async fn assign_resolved_variable(
  database : Database,
  name : String,
  operator : String,
  value : String,
) -> Unit {
  let state = database.expansion()
  if !valid_variable_name(name) {
    raise MakeError("invalid expanded variable name '\{name}'")
  }
  if database.command_line_variables.contains(name) {
    return
  }
  let variables = database.variables
  if operator == "?=" && variables.contains(name) {
    return
  }
  validate_special_assignment(name, operator, value)
  match operator {
    "!=" => {
      let script = expand(
        value,
        variables,
        {},
        0,
        cwd=database.cwd,
        exported=database.exported,
        state~,
      )
      variables[name] = {
        value: shell_result(
          script,
          variables,
          {},
          0,
          database.cwd,
          database.exported,
          state,
          trim_newlines=false,
        ),
        immediate: false,
      }
    }
    "?=" =>
      if !variables.contains(name) {
        variables[name] = { value, immediate: false, }
      }
    ":=" | "::=" | ":::=" => {
      let expanded = expand(
        value,
        variables,
        {},
        0,
        cwd=database.cwd,
        exported=database.exported,
        state~,
      )
      variables[name] = {
        value: if operator == ":::=" {
          expanded.replace_all(old="$", new="$$")
        } else {
          expanded
        },
        immediate: operator != ":::=",
      }
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
                state~,
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
  database.exported.defaults.remove(name)
}

///|
fn logical_lines(contents : String) -> Array[String] raise MakeError {
  let result : Array[String] = []
  let pending = StringBuilder()
  for raw_line in contents.split("\n") {
    let line = if raw_line.has_suffix("\r") {
      raw_line[:raw_line.length() - 1].to_owned()
    } else {
      raw_line.to_owned()
    }
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
  depth : Int32,
) -> Unit {
  if depth > 64 {
    raise MakeError("include nesting exceeds the recursion limit")
  }
  let mut current_rules : Array[Rule] = []
  let mut current_groups : Array[Prerequisites] = []
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
      for index, rule in current_rules {
        add_recipe(rule, current_groups[index], recipe)
      }
      continue
    }
    current_rules = []
    current_groups = []
    let line = trim_make_space_start(remove_comment(source_line))
    if line.trim().is_empty() {
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
        state=database.expansion(),
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
    if export_directive(line) is Some((exporting, contents)) {
      if contents.is_empty() {
        database.exported.all = exporting
        continue
      }
      match export_assignment(contents, exporting) {
        Some((name, operator, value, exporting)) => {
          let name = expand(
            name,
            database.variables,
            {},
            0,
            cwd=database.cwd,
            exported=database.exported,
            state=database.expansion(),
          )
          assign_resolved_variable(database, name, operator, value)
          mark_export(database, name, exporting)
        }
        _ =>
          for
            name in split_words(
              expand(
                contents,
                database.variables,
                {},
                0,
                cwd=database.cwd,
                exported=database.exported,
                state=database.expansion(),
              ),
            ) {
            mark_export(database, name, exporting)
          }
      }
      continue
    }
    if parse_assignment(line) is Some((name, operator, value)) {
      assign_variable(database, name, operator, value)
      continue
    }
    let (rule_line, inline_recipe) = split_inline_recipe(source_line)
    let rule_line = remove_comment(rule_line).trim_start().to_owned()
    guard split_rule_separator(rule_line, ':')
      is Some((targets_text, deps_text)) else {
      raise MakeError(
        "expected a rule or assignment at line \{line_number + 1}",
      )
    }
    if deps_text.has_prefix(":") {
      raise MakeError(
        "double-colon rules are outside the supported make profile",
      )
    }
    if parse_assignment(deps_text.trim_start().to_owned()) is Some(_) {
      raise MakeError(
        "target-specific variables are outside the supported make profile",
      )
    }
    if targets_text.trim_end().has_suffix("&") {
      raise MakeError("grouped targets are outside the supported make profile")
    }
    if split_rule_separator(deps_text, '|') is Some(_) {
      raise MakeError(
        "order-only prerequisites are outside the supported make profile",
      )
    }
    let static_pattern = split_rule_separator(deps_text, ':')
    let prerequisite_text = match static_pattern {
      Some((pattern, prerequisites)) if pattern.trim().contains("%") =>
        prerequisites
      _ => deps_text
    }
    let targets = split_words(
      expand(
        targets_text,
        database.variables,
        {},
        0,
        cwd=database.cwd,
        exported=database.exported,
        state=database.expansion(),
      ),
    )
    validate_rule_words(targets, [])
    let dependency_text = expand(
      prerequisite_text,
      database.variables,
      {},
      0,
      cwd=database.cwd,
      exported=database.exported,
      state=database.expansion(),
    )
    let dependencies = split_words(dependency_text)
    validate_rule_words(targets, dependencies)
    if targets.is_empty() {
      raise MakeError("rule has no target at line \{line_number + 1}")
    }
    if targets == [".SECONDEXPANSION"] {
      database.secondary_expansion = true
      continue
    }
    if targets == [".PHONY"] {
      for target in dependencies {
        match database.rules.get(target) {
          Some(rule) => rule.phony = true
          None =>
            database.rules[target] = {
              target,
              dependencies: [],
              groups: [],
              recipes: [],
              phony: true,
              stem: None,
            }
        }
      }
      continue
    }
    for target in targets {
      if target == ".EXPORT_ALL_VARIABLES" {
        database.exported.target_all = true
      }
      let (dependencies, stem) = match static_pattern {
        Some((pattern, _)) if pattern.trim().contains("%") => {
          let pattern = pattern.trim().to_owned()
          match pattern_match(pattern, target) {
            Some(stem) =>
              (dependencies.map(dep => replace_stem(dep, stem)), Some(stem))
            None => (dependencies.copy(), None)
          }
        }
        _ => (dependencies.copy(), None)
      }
      let group : Prerequisites = {
        text: match stem {
          Some(stem) => replace_stems(dependency_text, stem)
          None => dependency_text
        },
        secondary: database.secondary_expansion && dependency_text.contains("$"),
        has_recipe: false,
        stem,
      }
      let rule = match database.rules.get(target) {
        Some(existing) => {
          existing.dependencies.append(dependencies)
          existing.groups.push(group)
          if stem is Some(value) {
            existing.stem = Some(value)
          }
          existing
        }
        None => {
          let created : Rule = {
            target,
            dependencies: dependencies.copy(),
            groups: [group],
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
      current_groups.push(group)
      if inline_recipe is Some(recipe) {
        add_recipe(rule, group, recipe)
      }
    }
  }
  if active.length() != 1 {
    raise MakeError("missing endif")
  }
}

///|
fn path_in(cwd : String, path : String) -> String {
  if path == "" || @path.Path(path).is_absolute() {
    path
  } else {
    // Path.join would erase missing components and symlink-parent traversal.
    cwd + "/" + path
  }
}

///|
async fn newer(left : String, right : String) -> Bool {
  let (left_s, left_ns) = @fs.mtime(left)
  let (right_s, right_ns) = @fs.mtime(right)
  left_s > right_s || (left_s == right_s && left_ns > right_ns)
}

///|
async fn command_environment(
  database : Database,
  automatic~ : Map[String, String] = Map([]),
) -> Map[String, String] {
  let result : Map[String, String] = Map([])
  let state = database.expansion()
  if state.original.get("SHELL") is Some(shell) {
    result["SHELL"] = shell
  }
  for name in database.exported.names(database.variables) {
    if database.variables.contains(name) {
      result[name] = lookup_variable(
        name,
        database.variables,
        automatic,
        0,
        cwd=database.cwd,
        exported=database.exported,
        state~,
      )
    }
  }
  result["MAKELEVEL"] = (database.invocation_level + 1).to_string()
  if database.serial_children && result.get("MAKEFLAGS") is Some(flags) {
    result["MAKEFLAGS"] = serial_child_flags(flags)
  }
  if result.get("MAKEFLAGS") is Some(flags) {
    result["MAKEFLAGS"] = flags.replace_all(old="$", new="$$")
  }
  result
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
  if value.is_empty() || value.iter().any(char => char < '0' || char > '9') {
    return false
  }
  let count = @string.parse_int(value) catch { _ => return false }
  count > 0
}

///|
async fn run(arguments : Array[String]) -> Unit {
  let mut requested_file : String? = None
  let mut cwd = @env.current_dir().unwrap_or(".")
  let directories : Array[String] = []
  let mut silent = false
  let mut dry_run = false
  let mut always_make = false
  let mut keep_going = false
  let mut jobs = 1
  let mut explicit_jobs = false
  let original_environment = @process.default_environment()
  let environment_variables : Map[String, Variable] = Map([])
  for name, value in original_environment {
    environment_variables[name] = { value, immediate: name != "MAKEFLAGS", }
  }
  let decoded_flags = lookup_variable(
    "MAKEFLAGS",
    environment_variables,
    {},
    0,
    cwd~,
    exported=ExportPolicy::new(environment_variables.keys().collect()),
    state=Expansion::new(original=original_environment),
  )
  let inherited_flags = makeflag_words(decoded_flags)
  let inherited_arguments = inherited_make_arguments(
    inherited_flags,
    include_assignments=false,
  )
  let arguments = inherited_arguments + arguments
  let touch_targets : Map[String, Bool] = Map([])
  let mut options = true
  let targets : Array[String] = []
  let cli_assignments = inherited_make_assignments(inherited_flags)
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
      directories.push(arguments[index])
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
      explicit_jobs = index >= inherited_arguments.length()
      jobs = 0
      if index + 1 < arguments.length() &&
        positive_job_count(arguments[index + 1]) {
        index += 1
        jobs = @string.parse_int(arguments[index])
      }
    } else if options && argument.has_prefix("--jobs=") {
      explicit_jobs = index >= inherited_arguments.length()
      let value = argument[7:].to_owned()
      if !positive_job_count(value) {
        raise MakeError("the '-j' option requires a positive integer")
      }
      jobs = @string.parse_int(value)
    } else if options && argument.has_prefix("-j") && argument.length() > 2 {
      explicit_jobs = index >= inherited_arguments.length()
      if !positive_job_count(argument[2:].to_owned()) {
        raise MakeError("the '-j' option requires a positive integer")
      }
      jobs = @string.parse_int(argument[2:])
    } else if options && (argument == "-h" || argument == "--help") {
      @stdio.stdout.write(
        "Usage: make [-B] [-k] [-n] [-s] [-j [N]] [-W FILE] [-C DIR] [-f FILE] [VARIABLE=VALUE] [TARGET...]\n      --help      display this help and exit\n      --version   display version and exit\nSupports computed variables, named/default export and unexport, .EXPORT_ALL_VARIABLES, .SECONDEXPANSION and .SHELLSTATUS.\nMAKEFLAGS can inherit an existing POSIX FIFO jobserver; descriptor pipes and Windows semaphores are unavailable.\nWithout an inherited FIFO, recursive make runs one job per parent slot.\nShell test -s follows target metadata; unavailable target sizes are rejected.\nShell captures preserve status and output before errors; ignored recipe errors continue.\nOn POSIX, every file-test operand ending in a slash must name a directory.\nMakefile and dependency paths retain filesystem traversal; -C resolves each requested directory.\n",
      )
      return
    } else if options && argument.has_prefix("-") && argument != "-" {
      raise MakeError("unsupported option '\{argument}'")
    } else {
      match parse_assignment(argument) {
        Some(assignment) => cli_assignments.push(assignment)
        None => targets.push(argument)
      }
    }
    index += 1
  }
  for requested in directories {
    let directory = path_in(cwd, requested)
    if @fs.kind(directory) != Directory {
      raise MakeError("not a directory: \{requested}")
    }
    cwd = @fs.realpath(directory)
  }
  let variables : Map[String, Variable] = Map([])
  for name, value in @process.default_environment() {
    if name != "SHELL" && (value != "" || name == ".SHELLFLAGS") {
      validate_special_assignment(name, "=", value)
    }
    variables[name] = { value, immediate: true, }
  }
  // GNU ignores an inherited SHELL as an interpreter selector, while children
  // still receive its original environment value unless SHELL is exported.
  variables["SHELL"] = { value: "/bin/sh", immediate: true, }
  if !variables.contains(".SHELLFLAGS") {
    variables[".SHELLFLAGS"] = { value: "-c", immediate: true, }
  }
  variables["MAKEFLAGS"] = { value: decoded_flags, immediate: true, }
  let invocation = @env.args().get(0).unwrap_or("make")
  let own_path = path_in(@env.current_dir().unwrap_or("."), invocation)
  let quoted_path = "'" + own_path.replace_all(old="'", new="'\\''") + "'"
  variables["MAKE"] = {
    value: if invocation.has_suffix(".wasm") {
      "moonrun " + quoted_path + " --"
    } else {
      quoted_path
    },
    immediate: true,
  }
  variables["MAKELEVEL"] = {
    value: makelevel(variables).to_string(),
    immediate: true,
  }
  let command_line_variables : Map[String, Bool] = Map([])
  let database : Database = {
    cwd,
    variables,
    command_line_variables,
    exported: ExportPolicy::new(original_environment.keys().collect()),
    rules: {},
    default_target: None,
    secondary_expansion: false,
    invocation_level: 0,
    serial_children: true,
  }
  for name in ["SHELL", ".SHELLFLAGS", "MAKE"] {
    database.exported.defaults.add(name)
  }
  if original_environment.contains("SHELL") {
    database.exported.remove("SHELL")
  }
  for (raw_name, operator, value) in cli_assignments {
    let name = expand(
      raw_name,
      variables,
      {},
      0,
      cwd~,
      exported=database.exported,
    )
    if operator == "?=" && variables.contains(name) {
      continue
    }
    command_line_variables.remove(name)
    assign_resolved_variable(database, name, operator, value)
    command_line_variables[name] = true
    if name != "SHELL" && default_export_name(name) {
      database.exported.add(name)
    }
  }
  database.invocation_level = makelevel(variables)
  let authentication = if explicit_jobs {
    None
  } else {
    inherited_jobserver(inherited_flags)
  }
  database.serial_children = authentication is None
  let propagated_flags : Array[String] = []
  if silent {
    propagated_flags.push("-s")
  }
  if dry_run {
    propagated_flags.push("-n")
  }
  if always_make {
    propagated_flags.push("-B")
  }
  if keep_going {
    propagated_flags.push("-k")
  }
  match authentication {
    Some(value) => {
      propagated_flags.push("-j")
      propagated_flags.push(escape_makeflag("--jobserver-auth=" + value))
    }
    // Without a public FIFO creation API this process cannot create a GNU
    // jobserver. Recursive children keep one job per already occupied slot.
    None =>
      propagated_flags.push(
        if jobs == 0 {
          "-j"
        } else {
          "-j" + jobs.to_string()
        },
      )
  }
  if !command_line_variables.is_empty() {
    propagated_flags.push("--")
    let names = command_line_variables.keys().collect()
    names.sort()
    for name in names {
      let variable = variables[name]
      let assignment = if variable.immediate {
        name + ":=" + variable.value
      } else {
        name + "=" + variable.value
      }
      propagated_flags.push(escape_makeflag(assignment))
    }
  }
  variables["MAKEFLAGS"] = {
    value: propagated_flags.join(" "),
    immediate: true,
  }
  database.exported.add("MAKEFLAGS")
  let makefile = choose_makefile(cwd, requested_file)
  parse_makefile(
    @fs.read_file(makefile).text(),
    database,
    @path.Path(makefile).dirname().to_string(),
    0,
  )
  database.exported.finish_reading()
  let requested_targets = if targets.is_empty() {
    match database.default_target {
      Some(value) => [value]
      None => raise MakeError("Makefile contains no targets")
    }
  } else {
    targets
  }
  let final_flags = makeflag_words(
    lookup_variable(
      "MAKEFLAGS",
      variables,
      {},
      0,
      cwd~,
      exported=database.exported,
      state=database.expansion(),
    ),
  )
  let final_authentication = if explicit_jobs {
    None
  } else {
    match inherited_jobserver(final_flags) {
      Some(value) => Some(value)
      None => authentication
    }
  }
  database.serial_children = final_authentication is None
  let jobserver = match final_authentication {
    Some(value) => Some(Jobserver::open(value))
    None => None
  }
  defer (if jobserver is Some(server) { server.close() })
  let settings : Settings = apply_makefile_flags(
    {
      jobs,
      jobserver,
      expansion_lock: @async.Mutex(),
      cwd,
      silent,
      dry_run,
      always_make,
      keep_going,
      what_if: touch_targets,
    },
    inherited_make_arguments(final_flags, include_assignments=false),
  )
  build_targets(requested_targets, database, settings)
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("make 0.2.9\n")
    return
  }
  run(@env.args()[1:].to_owned()) catch {
    ExpansionFailure(message) => {
      @stdio.stderr.write("make: \{message}\n")
      @sys.exit(2)
    }
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
