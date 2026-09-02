///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("append", short='a'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tee: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: tee [-a] [FILE...]\n")
    return
  }
  let paths = parsed.operands
  let append = parsed.contains("append")
  let outputs : Array[@fs.File] = []
  let active : Array[Bool] = []
  let mut failed = false
  for path in paths {
    let file = @fsops.open_output(
      path,
      if append {
        AppendOrCreate
      } else {
        CreateOrTruncate
      },
    ) catch {
      err => {
        @stdio.stderr.write("tee: cannot open '\{path}': \{err}\n")
        failed = true
        continue
      }
    }
    outputs.push(file)
    active.push(true)
  }
  while @stdio.stdin.read_some(max_len=65536) is Some(chunk) {
    @stdio.stdout.write(chunk)
    for index, output in outputs {
      if active[index] {
        output.write(chunk) catch {
          err => {
            @stdio.stderr.write("tee: write failed: \{err}\n")
            active[index] = false
            failed = true
          }
        }
      }
    }
  }
  for output in outputs {
    output.close()
  }
  if failed {
    @sys.exit(1)
  }
}
