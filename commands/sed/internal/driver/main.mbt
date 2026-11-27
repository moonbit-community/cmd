///|
async fn run(args : ArrayView[String]) -> Int32 {
  let parsed = @cli.parse(args, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("sed \{MODULE_VERSION}\n")
    return 0
  }
  let scripts : Array[String] = []
  let expressions = parsed.values("expression")
  let script_files = parsed.values("file")
  let mut e = 0
  let mut f = 0
  for option in parsed.order {
    if option == "expression" {
      scripts.push(@bytere.argument(expressions[e]))
      e += 1
    }
    if option == "file" {
      scripts.push(@bytere.text(@fs.read_file(script_files[f]).binary()))
      f += 1
    }
  }
  let files = parsed.operands
  if scripts.is_empty() {
    guard !files.is_empty() else { fail("missing script") }
    scripts.push(@bytere.argument(files.remove(0)))
  }
  let source = scripts.join("\n")
  let commands = @program.compile(
    source,
    parsed.contains("regexp-extended") || parsed.contains("extended"),
  )
  let quiet = parsed.contains("quiet") ||
    parsed.contains("silent") ||
    source.has_prefix("#n")
  if files.is_empty() {
    files.push("-")
  }
  let runtime : Runtime = {
    previous: None,
    missing_newline: false,
    output: @stream.BlockWriter::new(@stdio.stdout),
  }
  let input : Input = {
    paths: files,
    index: 0,
    path: "",
    file: None,
    reader: None,
    buffer: b"",
    position: 0,
    number: 0,
    status: 0,
    output: runtime.output,
  }
  defer input.close()
  execute(commands, input, quiet, runtime)
  input.status
}

///|
pub async fn run_main() -> Unit {
  let status = run(@env.args()[1:]) catch {
    @program.SedLabelError(message) => {
      @stdio.stderr.write("sed: \{message}\n")
      4
    }
    @program.SedError(message) | @bytere.PatternError(message) => {
      @stdio.stderr.write("sed: \{message}\n")
      1
    }
    err => {
      @stdio.stderr.write("sed: \{err}\n")
      1
    }
  }
  if status != 0 {
    @env.exit(status)
  }
}
