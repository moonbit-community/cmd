///|
fn help_message() -> String {
  let message = metadata_help().strip_suffix("\n").unwrap().to_owned()
  message
}

///|
async fn process(
  reader : &@io.Reader,
  options : Options,
  known_size : Int64?,
) -> Unit {
  @async.with_task_group() <| group => {
    let outputs = Outputs::new(options, group)
    defer outputs.close()
    match options.layout {
      BytesPer(size) => split_bytes(reader, outputs, size)
      LinesPer(size) => split_lines(reader, outputs, size)
      LineBytes(size) => {
        let directory = @fs.tmpdir(prefix="split-")
        defer @fs.rmdir(directory, recursive=true)
        let spool = @fs.open(
          directory + "/record",
          mode=ReadWrite,
          create_mode=CreateNew,
          permission=0o600,
        )
        defer spool.close()
        split_line_bytes(reader, outputs, size, spool)
      }
      RoundRobin(count, selected) =>
        split_round_robin(reader, outputs, count, selected)
      Chunks(count, selected, lines) =>
        match known_size {
          Some(size) =>
            split_chunks(reader, outputs, size, count, selected, lines)
          None => {
            let directory = @fs.tmpdir(prefix="split-")
            defer @fs.rmdir(directory, recursive=true)
            let path = directory + "/input"
            let size = {
              let spool = @fs.open(
                path,
                mode=WriteOnly,
                create_mode=CreateNew,
                permission=0o600,
              )
              defer spool.close()
              let mut size = 0L
              while reader.read_some(max_len=65536) is Some(bytes) {
                spool.write(bytes)
                size = byte_position(size, bytes.length())
              }
              size
            }
            let spool = @fs.open(path, mode=ReadOnly)
            defer spool.close()
            split_chunks(spool, outputs, size, count, selected, lines)
          }
        }
    }
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("split \{MODULE_VERSION}\n")
    return
  }
  let parsed = parse_args(@env.args()[1:]) catch {
    @cli.CliError(message~, option~, ..) => {
      @stdio.stderr.write("split: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("split \{MODULE_VERSION}\n")
    return
  }
  try {
    let options = options(parsed)
    let input = parsed.operands.get(0).unwrap_or("-")
    if input == "-" {
      process(@stdio.stdin, options, None)
    } else {
      let file = @fs.open(input, mode=ReadOnly)
      defer file.close()
      let size = if file.kind() == Regular { Some(file.size()) } else { None }
      process(file, options, size)
    }
  } catch {
    SplitError(status, message) => {
      @stdio.stderr.write("split: \{message}\n")
      @env.exit(status)
    }
    error => {
      @stdio.stderr.write("split: \{error}\n")
      @env.exit(1)
    }
  }
}
