///|
async test "command README coordinates match source and preserve unpublished boundaries" {
  let root = if @fs.exists("tests/registry/registry.json") {
    ""
  } else if @fs.exists("registry/registry.json") {
    "../"
  } else {
    "../../"
  }
  for name in command_names(root + "commands") {
    let directory = root + "commands/" + name
    let module_text = @fs.read_file(directory + "/moon.mod").text()
    let version = dependency_manifest_field(module_text, "version")
    let readme = @fs.read_file(directory + "/README.md")
      .text()
      .replace_all(old="\r\n", new="\n")
    assert_true(readme.has_prefix("# " + name + "\n"))
    assert_true(readme.contains("MoonX"))
    for section in ["Supported scope", "Options", "Limitations", "Examples"] {
      assert_true(readme.contains("\n## " + section + "\n"))
    }
    assert_true(readme.contains("../../docs/compatibility.md"))
    if name == "timeout" {
      assert_true(
        readme.contains("moon run --target wasm --release commands/" + name),
      )
      assert_true(!readme.contains("moonx cli/" + name + "@"))
    } else {
      assert_true(readme.contains("moonx cli/" + name + "@" + version))
      if name == "rg" {
        assert_true(readme.contains("unpublished candidate"))
        assert_true(readme.contains("after publication"))
        assert_true(!readme.contains("moon run"))
      }
    }
  }
}
