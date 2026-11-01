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
    assert_true(readme.contains("../../docs/compatibility.md"))
    assert_true(readme.contains("../../docs/adr/"))
    let invocation = if name == "timeout" {
      assert_true(!readme.contains("moonx cli/" + name + "@"))
      "moon run --target wasm --release commands/" + name + " --"
    } else {
      "moonx cli/" + name + "@" + version
    }
    assert_true(
      readme
      .split("\n")
      .any(line => {
        let line = line.trim().to_owned()
        (line == invocation || line.contains(invocation + " ")) &&
        !line.contains("[") &&
        !line.contains("...")
      }),
      msg="missing concrete command example: " + name,
    )
  }
}
