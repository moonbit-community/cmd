///|
async fn run(args : ArrayView[String]) -> Int32 {
  let parsed = @cli.parse(args, [
    @cli.flag("quiet", short='n'),
    @cli.flag("silent"),
    @cli.flag("regexp-extended", short='E'),
    @cli.flag("extended", short='r'),
    @cli.option("expression", short='e'),
    @cli.option("file", short='f'),
    @cli.flag("help"),
    @cli.flag("version"),
  ])
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: sed [-nE] [-e SCRIPT] [-f SCRIPTFILE] [SCRIPT] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\nStream editor: p/d/q/=, s/RE/REPLACEMENT/[gNp], h/H/g/G/x, :/b/t/T, groups, n/N/P/D/a/i/c.\nAddresses: line number, $, /RE/, ranges and !. BRE default; -E enables ERE.\nBRE/ERE supports pattern backreferences and word assertions.\nIn-place editing and locale-aware matching are not supported.\n",
    )
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("sed 0.2.0\n")
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
  let commands = compile(
    source,
    parsed.contains("regexp-extended") || parsed.contains("extended"),
  )
  let quiet = parsed.contains("quiet") ||
    parsed.contains("silent") ||
    source.has_prefix("#n")
  if files.is_empty() {
    files.push("-")
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
  }
  defer input.close()
  let runtime : Runtime = { previous: None, missing_newline: false, }
  execute(commands, input, quiet, runtime)
  input.status
}

///|
async fn main {
  let status = run(@env.args()[1:]) catch {
    SedLabelError(message) => {
      @stdio.stderr.write("sed: \{message}\n")
      4
    }
    SedError(message) | @bytere.PatternError(message) => {
      @stdio.stderr.write("sed: \{message}\n")
      1
    }
    err => {
      @stdio.stderr.write("sed: \{err}\n")
      1
    }
  }
  if status != 0 {
    @sys.exit(status)
  }
}
