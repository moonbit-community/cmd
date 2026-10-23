///|
fn dependency_manifest_field(text : String, key : String) -> String raise {
  let prefix = key + " = "
  let values = []
  for line in text.split("\n") {
    if line.trim().strip_prefix(prefix) is Some(value) {
      values.push(value.to_owned())
    }
  }
  guard values.length() == 1 else {
    fail("dependency inventory requires one " + key + " field")
  }
  guard @json.parse(values[0]) is String(value) else {
    fail("dependency inventory requires a quoted " + key + " field")
  }
  value
}

///|
fn dependency_manifest_imports(text : String) -> Array[String] raise {
  let imports = []
  let mut in_imports = false
  let mut blocks = 0
  for line in text.split("\n") {
    let line = line.trim()
    if line == "import {" {
      blocks += 1
      in_imports = true
    } else if in_imports && line == "}" {
      in_imports = false
    } else if in_imports && line != "" {
      let literal = line.strip_suffix(",").unwrap_or(line).trim().to_owned()
      guard @json.parse(literal) is String(coordinate) else {
        fail("dependency inventory requires registry coordinates")
      }
      imports.push(coordinate)
    }
  }
  guard blocks == 1 && !in_imports else {
    fail("dependency inventory requires one complete import block")
  }
  imports
}

///|
async test "workspace dependency manifests keep one async baseline and the selected local core coordinate" {
  let root = if @fs.exists("tests/registry/registry.json") {
    ""
  } else if @fs.exists("registry/registry.json") {
    "../"
  } else {
    "../../"
  }
  let core = @fs.read_file(root + "core/moon.mod").text()
  assert_eq(dependency_manifest_field(core, "name"), "cli/core")
  let core_coordinate = "cli/core@" + dependency_manifest_field(core, "version")
  let commands = command_names(root + "commands")
  assert_eq(commands.length(), 79)
  let independent = ["echo", "false", "printf", "seq", "sleep", "true"]
  let modules = ["core", "tests"]
  for command in commands {
    modules.push("commands/" + command)
  }
  assert_eq(modules.length(), 81)
  for directory in modules {
    let text = @fs.read_file(root + directory + "/moon.mod").text()
    let expected_name = if directory == "core" {
      "cli/core"
    } else if directory == "tests" {
      "mooxCLI/cmd-tests"
    } else {
      "cli/" + directory.strip_prefix("commands/").unwrap().to_owned()
    }
    assert_eq(dependency_manifest_field(text, "name"), expected_name)
    let imports = dependency_manifest_imports(text)
    assert_eq(
      imports.filter(coordinate => coordinate.has_prefix("moonbitlang/async@")),
      ["moonbitlang/async@0.22.5"],
    )
    let needs_core = directory == "tests" ||
      (
        directory.has_prefix("commands/") &&
        !independent.contains(
          directory.strip_prefix("commands/").unwrap().to_owned(),
        )
      )
    let core_imports = imports.filter(coordinate => {
      coordinate.has_prefix("cli/core@")
    })
    if needs_core {
      assert_eq(core_imports.length(), 1)
      // Unchanged commands may retain the published core; the harness follows
      // the workspace candidate instead of forcing every command to migrate.
      if directory == "tests" {
        assert_eq(core_imports, [core_coordinate])
      } else {
        assert_true(
          ["cli/core@0.7.0", core_coordinate].contains(core_imports[0]),
        )
      }
    } else {
      assert_eq(core_imports, [])
    }
  }
  let members = []
  for line in @fs.read_file(root + "moon.work").text().split("\n") {
    let line = line.trim()
    if line.has_prefix("\"") {
      let literal = line.strip_suffix(",").unwrap_or(line).trim().to_owned()
      guard @json.parse(literal) is String(module_path) else {
        fail("workspace member must be a quoted module path")
      }
      members.push(
        module_path.strip_prefix("./").unwrap_or(module_path[:]).to_owned(),
      )
    }
  }
  modules.sort()
  members.sort()
  assert_eq(members, modules)
}
