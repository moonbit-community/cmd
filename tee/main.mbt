///|
async fn main {
  let args = @env.args()[1:]
  let paths : Array[String] = []
  let mut append = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-a" || arg == "--append") {
      append = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: tee [-a] [FILE...]\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("tee: unsupported option: '\{arg}'\n")
      @sys.exit(1)
      return
    } else {
      paths.push(arg)
    }
  }
  let outputs : Array[@fs.File] = []
  let active : Array[Bool] = []
  let mut failed = false
  for path in paths {
    let file = @fs.open(
      path,
      mode=WriteOnly,
      append~,
      create_mode=if append { OpenOrCreate } else { CreateOrTruncate },
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
