///|
priv suberror RealpathError {
  RealpathError(String)
}

///|
async fn canonicalize(
  path : String,
  canonicalize_existing : Bool,
) -> String raise RealpathError {
  @fs.realpath(path) catch {
    error => {
      let description = if canonicalize_existing {
        "cannot canonicalize existing path"
      } else {
        "cannot canonicalize path"
      }
      raise RealpathError("\{description} '\{path}': \{error}")
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("canonicalize-existing", short='e'),
    @cli.flag("zero", short='z'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("realpath: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    let message =
      #|Usage: realpath [-e] [-z] NAME...
      #|  -e, --canonicalize-existing  require every path component to exist
      #|  -z, --zero                   separate output with NUL bytes
    @stdio.stdout.write(message)
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("realpath (moonbit cmd) \{command_version}\n")
    return
  }
  if parsed.operands.is_empty() {
    @stdio.stderr.write("realpath: missing operand\n")
    @sys.exit(1)
    return
  }
  let canonicalize_existing = parsed.contains("canonicalize-existing")
  let separator = if parsed.contains("zero") { "\u0000" } else { "\n" }
  let mut failed = false
  for path in parsed.operands {
    let canonical = canonicalize(path, canonicalize_existing) catch {
      RealpathError(message) => {
        @stdio.stderr.write("realpath: \{message}\n")
        failed = true
        continue
      }
    }
    @stdio.stdout.write(canonical + separator)
  }
  if failed {
    @sys.exit(1)
  }
}
