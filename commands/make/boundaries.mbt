///|
fn make_function_name(reference : String) -> String? {
  let chars = reference.iter().collect()
  let mut end = 0
  while end < chars.length() &&
        !(chars[end] is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
    end += 1
  }
  if end == chars.length() {
    None
  } else {
    Some(String::from_array(chars[:end]))
  }
}

///|
fn reject_unsupported_function(reference : String) -> Unit raise MakeError {
  guard make_function_name(reference) is Some(name) else { return }
  // GNU make 4.4.1 function_table_init; detect lazy functions before touching
  // their arguments. Unknown names retain ordinary variable-name expansion.
  if [
      "abspath", "addprefix", "addsuffix", "basename", "dir", "notdir", "subst",
      "suffix", "filter", "filter-out", "findstring", "firstword", "flavor", "join",
      "lastword", "patsubst", "realpath", "sort", "strip", "wildcard", "word", "wordlist",
      "words", "origin", "foreach", "let", "call", "info", "error", "warning", "intcmp",
      "if", "or", "and", "value", "eval", "file",
    ].contains(name) {
    raise MakeError(
      "GNU function '\{name}' is outside the supported make profile",
    )
  }
}

///|
fn validate_special_assignment(
  name : String,
  operator : String,
  value : String,
) -> Unit raise MakeError {
  if name == "SHELL" || name == ".SHELLFLAGS" {
    let literal = value.trim().to_owned()
    let accepted = operator is ("=" | ":=" | "::=" | "?=") &&
      (if name == "SHELL" {
        literal == "sh" || literal == "/bin/sh"
      } else {
        literal == "-c"
      })
    if !accepted {
      raise MakeError(
        "\{name} requires the literal built-in sh profile (SHELL=sh or /bin/sh, .SHELLFLAGS=-c); custom interpreters and flags are unsupported",
      )
    }
  }
  if [
      ".RECIPEPREFIX", ".DEFAULT_GOAL", ".EXTRA_PREREQS", "VPATH", "GPATH", "MAKEOVERRIDES",
      "GNUMAKEFLAGS", "MAKEFILES",
    ].contains(name) {
    raise MakeError(
      "control variable '\{name}' is outside the supported make profile",
    )
  }
}

///|
fn validate_rule_words(
  targets : Array[String],
  dependencies : Array[String],
) -> Unit raise MakeError {
  for target in targets {
    if target == "&" {
      raise MakeError("grouped targets are outside the supported make profile")
    }
    if [
        ".ONESHELL", ".POSIX", ".DEFAULT", ".SUFFIXES", ".IGNORE", ".SILENT", ".NOTPARALLEL",
        ".DELETE_ON_ERROR", ".PRECIOUS", ".SECONDARY", ".INTERMEDIATE", ".NOTINTERMEDIATE",
        ".LOW_RESOLUTION_TIME", ".EXPORT_ALL_VARIABLES", ".WAIT",
      ].contains(target) {
      raise MakeError(
        "special target '\{target}' is outside the supported make profile",
      )
    }
  }
  for word in targets + dependencies {
    if !word.contains("$(") && word.contains("(") && word.has_suffix(")") {
      raise MakeError("archive members are outside the supported make profile")
    }
  }
  if dependencies.any(word => word.contains("|") || word == ".WAIT") {
    raise MakeError(
      "order-only and .WAIT prerequisites are outside the supported make profile",
    )
  }
}

///|
fn split_rule_separator(text : String, separator : Char) -> (String, String)? {
  let chars = text.iter().collect()
  let closes : Array[Char] = []
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\\' {
      index += 2
      continue
    }
    if chars[index] == '#' && closes.is_empty() {
      return None
    }
    if chars[index] == '$' && chars.get(index + 1) is Some('(' | '{' as open) {
      closes.push(if open == '(' { ')' } else { '}' })
      index += 2
      continue
    }
    if closes.last() == Some(')') && chars[index] == '(' {
      closes.push(')')
    } else if closes.last() == Some('}') && chars[index] == '{' {
      closes.push('}')
    } else if closes.last() == Some(chars[index]) {
      ignore(closes.pop())
    } else if chars[index] == separator && closes.is_empty() {
      return Some(
        (
          String::from_array(chars[:index]),
          String::from_array(chars[index + 1:]),
        ),
      )
    }
    index += 1
  }
  None
}

///|
fn split_inline_recipe(text : String) -> (String, String?) {
  match split_rule_separator(text, ';') {
    Some((rule, recipe)) => (rule, Some(recipe))
    None => (text, None)
  }
}

///|
fn add_recipe(rule : Rule, group : Prerequisites, recipe : String) -> Unit {
  if !group.has_recipe {
    rule.recipes.clear()
    for previous in rule.groups {
      previous.has_recipe = false
    }
    group.has_recipe = true
    ignore(rule.groups.pop())
    rule.groups.insert(0, group)
  }
  rule.recipes.push(recipe)
}
