///|
async fn feed(
  reader : &@io.BinaryReader,
  session : @awk.Session,
  host : @streams.Host,
) -> Unit {
  let records = @stream.RecordReader::from_binary(reader)
  while records.next_batch() is Some(batch) {
    while batch.next() is Some(record) {
      let value = @utf8.decode(record.data, ignore_bom=false) catch {
        _ => raise Failure("invalid UTF-8 input")
      }
      session.feed(value)
      host.flush()
      if session.is_stopped() || session.should_skip_file() {
        return
      }
    }
  }
}

///|
async fn feed_files(session : @awk.Session, host : @streams.Host) -> Unit {
  let mut had_file = false
  let mut i = 1
  while i < session.argument_count() && !session.is_stopped() {
    let path = session.argument(i)
    i += 1
    if path.is_empty() {
      continue
    }
    if assignment(path) is Some((key, value)) {
      session.assign(key, value)
      continue
    }
    had_file = true
    session.begin_file(path)
    if path == "-" {
      feed(@stdio.stdin, session, host)
    } else {
      let file = @fs.open(path, mode=ReadOnly)
      defer file.close()
      feed(file, session, host)
    }
  }
  if !had_file && !session.is_stopped() {
    session.begin_file("-")
    feed(@stdio.stdin, session, host)
  }
}

///|
async fn execute(options : Invocation, host : @streams.Host) -> Int32 {
  let session = @awk.new_session(
    options.program,
    input_mode=if options.csv { "csv" } else { "" },
    environment=@env.get_env_vars(),
    arguments=["awk", ..options.operands],
    clock_seconds=@env.now().to_double() / 1000.0,
    input=Some(value => host.input(value)),
    io=Some(value => host.io(value)),
    output_sink=Some(value => host.output(value)),
  )
  defer session.close_input()
  defer session.close_io()
  for pair in options.assignments {
    let (key, value) = pair
    session.assign(key, value)
  }
  let (separator, main_getline, redirect_stdin) = input_features(
    options.program,
  )
  let pull = options.csv ||
    separator ||
    main_getline ||
    options.assignments.any(pair => pair.0 == "RS" || pair.0 == "INPUTMODE") ||
    options.operands.any(arg => {
      arg.has_prefix("RS=") || arg.has_prefix("INPUTMODE=")
    })
  let stdin_operand = options.operands.all(arg => {
      arg.is_empty() || assignment(arg) is Some(_)
    }) ||
    options.operands.contains("-") ||
    options.program.contains("ARGV")
  let early_stdin = (stdin_operand && main_getline) || redirect_stdin
  if early_stdin {
    host.stage_stdin(@stdio.stdin.read_all())
  }
  session.begin()
  host.flush()
  if session.needs_input() && !session.is_stopped() {
    if pull {
      if stdin_operand && !early_stdin {
        host.stage_stdin(@stdio.stdin.read_all())
      }
      while session.advance() {
        host.flush()
      }
    } else {
      feed_files(session, host)
    }
  }
  session.finish()
  host.flush()
  session.exit_status()
}

///|
pub async fn run_main() -> Unit {
  let args = @env.args()[1:]
  if args == ["--help"] {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if args == ["--version"] {
    @stdio.stdout.text.write("awk \{MODULE_VERSION}\n")
    return
  }
  let host = @streams.Host::new()
  let code = execute(invocation(args), host) catch {
    err => {
      host.flush()
      @stdio.stderr.text.write("awk: " + host.diagnostic(err) + "\n")
      2
    }
  }
  if code != 0 {
    @env.exit(code)
  }
}
