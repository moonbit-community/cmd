///|
fn admission_has_unsafe_source(
  command : String,
  entry : String,
  source : String,
) -> Bool {
  // These two make expressions describe the built-in interpreter profile.
  // They never launch the named host executable. Keep exceptions exact and
  // file-scoped; any host path in an invocation still fails admission.
  let source = if command == "make" && entry == "boundaries.mbt" {
    source.replace_all(
      old="literal == \"/bin/sh\"",
      new="literal == \"<builtin-sh-profile>\"",
    )
  } else if command == "make" && entry == "main.mbt" {
    source.replace_all(
      old="variables[\"SHELL\"] = { value: \"/bin/sh\", immediate: true, }",
      new="variables[\"SHELL\"] = { value: \"<builtin-sh-profile>\", immediate: true, }",
    )
  } else {
    source
  }
  source.contains("spawn_orphan") || source.contains("\"/bin/")
}

///|
// Only complete, explicitly test-scoped import blocks can lose production
// authority. This accepts the formatter's line-based moon.pkg import syntax;
// unfamiliar import syntax fails admission instead of being silently skipped.
fn admission_manifest_line(line : String) -> String raise {
  let mut quoted = false
  let mut escaped = false
  for index in 0..<line.length() {
    let unit = line[index]
    if quoted {
      if escaped {
        escaped = false
      } else if unit == '\\' {
        escaped = true
      } else if unit == '"' {
        quoted = false
      }
    } else if unit == '"' {
      quoted = true
    } else if unit == '/' && index + 1 < line.length() {
      if line[index + 1] == '/' {
        return line[:index].trim().to_owned()
      }
      guard line[index + 1] != '*' else {
        fail("unsupported moon.pkg block comment in admission scan")
      }
    }
  }
  guard !quoted else { fail("unterminated moon.pkg string in admission scan") }
  line.trim().to_owned()
}

///|
fn admission_import_entry(line : String) -> (String, Bool) raise {
  let comma = line.has_suffix(",")
  let entry = line.strip_suffix(",").unwrap_or(line[:]).trim().to_owned()
  guard entry.has_prefix("\"") else {
    fail("unrecognized moon.pkg import entry")
  }
  let mut escaped = false
  let mut closing = -1
  for index in 1..<entry.length() {
    if escaped {
      escaped = false
    } else if entry[index] == '\\' {
      escaped = true
    } else if entry[index] == '"' {
      closing = index
      break
    }
  }
  guard closing > 0 else { fail("unterminated moon.pkg import path") }
  guard @json.parse(entry[:closing + 1].to_owned()) is String(path) &&
    path != "" else {
    fail("invalid moon.pkg import path")
  }
  let suffix = entry[closing + 1:].trim()
  if !suffix.is_empty() {
    guard suffix.strip_prefix("@") is Some(import_alias) &&
      !import_alias.is_empty() else {
      fail("unrecognized moon.pkg import alias")
    }
    for part in import_alias.split("/") {
      guard !part.is_empty() else { fail("invalid moon.pkg import alias") }
      for index, unit in part {
        guard (unit >= 'a' && unit <= 'z') ||
          (unit >= 'A' && unit <= 'Z') ||
          unit == '_' ||
          (index > 0 && unit >= '0' && unit <= '9') else {
          fail("invalid moon.pkg import alias")
        }
      }
    }
  }
  (path, comma)
}

///|
fn admission_has_unquoted_import(line : String) -> Bool {
  let mut quoted = false
  let mut escaped = false
  for index in 0..<line.length() {
    let unit = line[index]
    if quoted {
      if escaped {
        escaped = false
      } else if unit == '\\' {
        escaped = true
      } else if unit == '"' {
        quoted = false
      }
    } else if unit == '"' {
      quoted = true
    } else if line[index:].has_prefix("import") {
      let end = index + 6
      let before = index == 0 ||
        !(line[index - 1] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_'))
      let after = end == line.length() ||
        !(line[end] is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_'))
      if before && after {
        return true
      }
    }
  }
  false
}

///|
fn admission_production_imports(manifest : String) -> Array[String] raise {
  let production : Array[String] = []
  let pending : Array[String] = []
  let mut in_import = false
  let mut needs_close = false
  for source_line in manifest.split("\n") {
    let line = admission_manifest_line(source_line.to_owned())
    if line.is_empty() {
      continue
    }
    if !in_import {
      if line.has_prefix("import") {
        guard line == "import {" else {
          fail("unrecognized moon.pkg import block")
        }
        in_import = true
        needs_close = false
        pending.clear()
      } else if line == "for" || line.has_prefix("for ") {
        fail("detached moon.pkg import scope")
      } else if admission_has_unquoted_import(line) {
        fail("unrecognized moon.pkg import position")
      }
      continue
    }
    if line.has_prefix("}") {
      let scope = line[1:].trim()
      if scope.is_empty() {
        production.append(pending)
      } else {
        guard scope == "for \"wbtest\"" || scope == "for \"test\"" else {
          fail("unrecognized moon.pkg import scope")
        }
      }
      in_import = false
      pending.clear()
    } else {
      guard !needs_close else { fail("missing moon.pkg import separator") }
      let (path, comma) = admission_import_entry(line)
      pending.push(path)
      needs_close = !comma
    }
  }
  guard !in_import else { fail("unterminated moon.pkg import block") }
  production
}

///|
fn admission_has_process_authority(manifest : String) -> Bool raise {
  admission_production_imports(manifest).any(path => {
    ["moonbitlang/async/process", "cli/core/process", "cli/core/shell"].any(authority => {
      path == authority || path.has_prefix(authority + "/")
    })
  })
}

///|
async fn check_admission(root : String, failures : Array[String]) -> Unit {
  let expected_restricted = [
    "chmod", "curl", "env", "find", "make", "rg", "sh", "split", "timeout", "typst",
    "wget", "xargs",
  ]
  let catalog = @catalog.commands()
  let mut default_count = 0
  let mut restricted_count = 0
  for contract in catalog {
    if contract.tier == Restricted {
      restricted_count += 1
    } else {
      default_count += 1
    }
    let manifest_path = root_path(
      root,
      "commands/" + contract.name + "/moon.pkg",
    )
    let manifest = @fs.read_file(manifest_path).text() catch {
      err => {
        failures.push("\{contract.name}: cannot read moon.pkg: \{err}")
        continue
      }
    }
    record(
      manifest.contains("supported_targets = \"native+wasm\"") ||
      manifest.contains("supported_targets = \"wasm\""),
      "\{contract.name}: Wasm product target is missing",
      failures,
    )
    if contract.tier != Restricted {
      let has_process_authority = admission_has_process_authority(manifest) catch {
        error => {
          failures.push(
            "\{contract.name}: cannot establish production imports: \{error}",
          )
          continue
        }
      }
      record(
        !has_process_authority,
        "\{contract.name}: non-restricted command acquired process authority",
        failures,
      )
    } else {
      let command_dir = root_path(root, "commands/" + contract.name)
      let entries = @fs.readdir(
        command_dir,
        include_hidden=true,
        include_special=false,
        sort=false,
      )
      for entry in entries {
        if entry.has_suffix(".mbt") {
          let source = @fs.read_file(root_path(command_dir, entry)).text()
          record(
            !admission_has_unsafe_source(contract.name, entry, source),
            "\{contract.name}: source contains an unsafe direct host path",
            failures,
          )
        }
      }
    }
  }
  record(
    default_count == 69,
    "default allow tier must contain 69 commands",
    failures,
  )
  record(
    restricted_count == 13,
    "restricted tier must contain 13 commands",
    failures,
  )
  for name in expected_restricted {
    match @catalog.find(name) {
      Some(contract) =>
        record(
          contract.tier == Restricted,
          "\{name}: must remain restricted",
          failures,
        )
      None => failures.push("\{name}: missing from command catalog")
    }
  }
  for name in ["make", "sh", "xargs"] {
    match @catalog.find(name) {
      Some(contract) =>
        record(
          @catalog.releasable(contract),
          "\{name}: direct-child semantics must not require process groups",
          failures,
        )
      None => ()
    }
  }
  match @catalog.find("timeout") {
    Some(contract) =>
      record(
        !@catalog.releasable(contract),
        "timeout: must remain gated without process-group cancellation",
        failures,
      )
    None => ()
  }
}
