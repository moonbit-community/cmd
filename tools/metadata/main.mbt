///|
async fn main {
  let args = @env.args()[1:]
  guard args is [mode] && ["check", "update"].contains(mode) else {
    fail("Usage: moon run tools/metadata -- check|update")
  }
  let commands : Array[String] = []
  for name in @fs.readdir("commands") {
    if !name.has_prefix(".") &&
      @fs.kind("commands/" + name, follow_symlink=false) is Directory {
      commands.push(name)
    }
  }
  commands.sort_by((left, right) => left.lexical_compare(right))
  assert_eq(commands.length(), 82)
  let declarations : Array[Metadata] = []
  for command in commands {
    let metadata : Metadata = @json.from_json(
      @json.parse(@fs.read_file("commands/" + command + "/options.json").text()),
    )
    validate(metadata)
    validate_help(metadata)
    assert_eq(metadata.command, command)
    for source in metadata.adapter_sources {
      guard !source.has_prefix("/") &&
        !source.contains("..") &&
        @fs.exists("commands/" + command + "/" + source) else {
        fail("missing command metadata adapter: " + command + "/" + source)
      }
    }
    generate(metadata, mode == "check")
    declarations.push(metadata)
  }
  generate_catalog(declarations, mode == "check")
  generate_shared(declarations, mode == "check")
  println("82 command metadata declarations verified")
}
