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
      "Usage: sed [-nE] [-e SCRIPT] [-f SCRIPTFILE] [SCRIPT] [FILE...]\n      --help      display this help and exit\n      --version   display version and exit\nStream editor: p, d, q, =, s/RE/REPLACEMENT/[gNp].\nAddresses: line number, $, /RE/, ranges and !. BRE default; -E enables ERE.\nIn-place editing, hold space, branches, groups and regex backreferences are not supported.\n",
    )
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("sed 0.1.2\n")
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
  let need_last = commands.any(c => {
    c.first is Some(Last) || c.last is Some(Last)
  })
  let mut number = 0
  let mut status = 0
  let mut pending : @stream.Line? = None
  let runtime : Runtime = { previous: None, missing_newline: false, }
  for path in files {
    let quit = try {
      let handle = if path == "-" {
        None
      } else {
        Some(@fs.open(path, mode=ReadOnly))
      }
      defer (if handle is Some(file) { file.close() })
      let reader : &@io.Reader = match handle {
        Some(file) => (file : &@io.Reader)
        None => (@stdio.stdin : &@io.Reader)
      }
      let scanner = @stream.LineScanner::new(reader)
      let mut quit = false
      while scanner.next() is Some(line) {
        if need_last {
          if pending is Some(previous) {
            number += 1
            if execute_line(commands, previous, number, false, quiet, runtime) {
              quit = true
              break
            }
          }
          pending = Some(line)
        } else {
          number += 1
          if execute_line(commands, line, number, false, quiet, runtime) {
            quit = true
            break
          }
        }
      }
      quit
    } catch {
      SedError(_) as err => raise err
      @bytere.PatternError(_) as err => raise err
      err => {
        @stdio.stderr.write("sed: \{path}: \{err}\n")
        status = 2
        false
      }
    }
    if quit {
      return status
    }
  }
  if pending is Some(line) {
    ignore(execute_line(commands, line, number + 1, true, quiet, runtime))
  }
  status
}

///|
async fn main {
  let status = run(@env.args()[1:]) catch {
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
