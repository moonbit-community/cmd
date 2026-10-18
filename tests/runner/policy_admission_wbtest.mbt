///|
test "policy admission separates complete test scopes from production imports" {
  let manifest =
    #|import {
    #|  "cli/core/fsops",
    #|}
    #|
    #|import {
    #|  "moonbitlang/async/process" @observer,
    #|  "moonbitlang/core/json",
    #|} for "wbtest" // Fixed host observer used only by package tests.
    #|
    #|import {
    #|  "cli/core/process" @process_test,
    #|  "cli/core/shell" @shell_test
    #|} for "test"
    #|
    #|supported_targets = "native+wasm"
    #|pkgtype(kind: "executable")
  assert_eq(admission_production_imports(manifest), ["cli/core/fsops"])
  assert_false(admission_has_process_authority(manifest))
  for
    authority in [
      "moonbitlang/async/process", "cli/core/process", "cli/core/shell",
    ] {
    let production = "import {\n  \"" + authority + "\" @renamed,\n}\n"
    assert_true(admission_has_process_authority(production + manifest))
    assert_true(admission_has_process_authority(manifest + "\n" + production))
  }
  assert_true(
    admission_has_process_authority(
      "import {\n  \"cli/core/process/internal\" @internal/observer,\n}\n",
    ),
  )
}

///|
test "policy admission rejects unknown incomplete and mixed import syntax" {
  for
    authority in [
      "moonbitlang/async/process", "cli/core/process", "cli/core/shell",
    ] {
    for
      manifest in [
        "supported_targets = \"native+wasm\" import { \"" + authority + "\" }\n",
        "pkgtype(kind: \"executable\") import {\n  \"" + authority + "\",\n}\n",
      ] {
      try admission_has_process_authority(manifest) catch {
        _ => ()
      } noraise {
        _ => fail("imports after another statement must fail policy admission")
      }
    }
  }
  for
    manifest in [
      "import {\n  \"moonbitlang/async/process\",\n} for \"benchmark\"\n", "import {\n  \"moonbitlang/async/process\",\n} for\n",
      "import {\n  \"moonbitlang/async/process\",\n} for \"wbtest\" for \"test\"\n",
      "import {\n  \"moonbitlang/async/process\",\n", "import {\n  \"moonbitlang/async/process\",\n}\nfor \"wbtest\"\n",
      "import { \"moonbitlang/async/process\" } for \"wbtest\"\n", "import {\n  \"moonbitlang/async/process\" @observer extra,\n} for \"wbtest\"\n",
      "import {\n  \"moonbitlang/async/process\" @,\n} for \"wbtest\"\n", "import {\n  \"moonbitlang/async/process\"\n  \"cli/core/cli\",\n} for \"wbtest\"\n",
      "import {\n  \"moonbitlang/async/process,\n} for \"wbtest\"\n", "import {\n  \"cli/core/cli\",\nimport {\n  \"moonbitlang/async/process\",\n} for \"wbtest\"\n",
      "import {\n  \"moonbitlang/async/process\",\n} for [\"wbtest\", \"production\"]\n",
    ] {
    try admission_has_process_authority(manifest) catch {
      _ => ()
    } noraise {
      _ => fail("unrecognized import syntax must fail policy admission")
    }
  }
}

///|
test "policy admission decodes import paths and ignores only actual comments" {
  let production =
    #|// import {
    #|//   "cli/core/shell",
    #|// } for "wbtest"
    #|import {
    #|  "moonbitlang/async/\u0070rocess" @observer, // Production authority.
    #|}
  assert_true(admission_has_process_authority(production))
  let quoted_paths =
    #|import {
    #|  "example/for \"wbtest\"" @quoted,
    #|  "example/path//segment" @comment_text,
    #|}
  assert_eq(admission_production_imports(quoted_paths), [
    "example/for \"wbtest\"", "example/path//segment",
  ])
  let quoted_configuration =
    #|supported_targets = "native+wasm" // import { "cli/core/process" }
    #|pkgtype(kind: "executable")
    #|options(warnings: "import { \"cli/core/shell\" }")
    #|unused_import = false
    #|preimport = false
    #|x_import_y = false
  assert_eq(admission_production_imports(quoted_configuration), [])
}

///|
async test "policy admission accepts the mv test observer without production process authority" {
  let root = workspace_root()
  let manifest = @fs.read_file(root + "/commands/mv/moon.pkg").text()
  assert_true(manifest.contains("\"moonbitlang/async/process\""))
  assert_true(manifest.contains("} for \"wbtest\""))
  assert_false(admission_has_process_authority(manifest))
}
