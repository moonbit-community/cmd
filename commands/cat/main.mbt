///|
fn help_message() -> String {
  let message =
    #|Usage: cat [FILE...]
    #|
    #|Concatenate FILEs (or stdin) to standard output, byte-transparently:
    #|no decoding, no newline normalization. Use '-' or no file for stdin.
    #|
    #|  -h, --help  Show this help message.
  message
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [@cli.flag("help", short='h')]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cat: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let operands = parsed.operands
  let sources = if operands.is_empty() { ["-"][:] } else { operands }
  if operands.is_empty() {
    @cli.warn_stdin_wait("cat")
  }
  let mut failed = false
  for path in sources {
    try {
      if path == "-" {
        @stdio.stdout.write_reader(@stdio.stdin)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        @stdio.stdout.write_reader(file)
      }
    } catch {
      err => {
        @stdio.stderr.write("cat: \{err}\n")
        failed = true
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
