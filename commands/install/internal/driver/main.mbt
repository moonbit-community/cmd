///|
async fn report(path : String, error : Error) -> Unit {
  let message = match error {
    Failure(reason) => reason
    @cli.CliError(option~, message~, ..) => message + ": " + option
    other => other.to_string()
  }
  @stdio.stderr.text.write(
    "install: " + (if path == "" { "" } else { path + ": " }) + message + "\n",
  )
}

///|
async fn run(args : ArrayView[String]) -> Int32 {
  let parsed = @cli.parse(args, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("install \{MODULE_VERSION}\n")
    return 0
  }
  guard !parsed.operands.is_empty() else { raise Failure("missing operand") }
  guard @platform.permission_mutation_supported() else {
    raise Failure("POSIX permission setting is unavailable on this host")
  }
  let permission = @copy.mode(parsed.last_value("mode").unwrap_or("755"))
  let mut status = 0
  if parsed.contains("directory") {
    for path in parsed.operands {
      @copy.directory(path, permission) catch {
        error => {
          report(path, error)
          status = 1
        }
      }
    }
  } else {
    let args = parsed.operands
    guard args.length() >= 2 else { raise Failure("missing destination") }
    let dest = args.last().unwrap()
    let directory = @copy.destination_is_directory(dest)
    guard directory || args.length() == 2 else {
      raise Failure("multiple sources require a destination directory")
    }
    for src in args[:args.length() - 1] {
      @copy.file(
        src,
        if directory {
          @fsops.join(dest, @fsops.basename(src))
        } else {
          dest
        },
        permission,
        leading=parsed.contains("leading"),
      ) catch {
        error => {
          report(src, error)
          status = 1
        }
      }
    }
  }
  status
}

///|
pub async fn run_main() -> Unit {
  let status = run(@env.args()[1:]) catch {
    error => {
      report("", error)
      1
    }
  }
  if status != 0 {
    @env.exit(status)
  }
}
