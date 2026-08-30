///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("silent", short='s'),
    @cli.flag("show-error", short='S'),
    @cli.flag("fail", short='f'),
    @cli.option("output", short='o'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("curl: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: curl [-sSf] [-o FILE] URL\n")
    return
  }
  let output_path = parsed.last_value("output")
  let fail_on_http_error = parsed.contains("fail")
  let silent = parsed.last_occurrence(["silent", "show-error"]) ==
    Some("silent")
  let urls = parsed.operands
  let mut failed = false
  let target = match urls {
    [value] => value
    [] => {
      @stdio.stderr.write("curl: missing URL\n")
      @sys.exit(2)
      return
    }
    _ => {
      @stdio.stderr.write("curl: only one URL is supported\n")
      @sys.exit(2)
      return
    }
  }
  let destination = match output_path {
    Some("-") => None
    other => other
  }
  @netops.fetch(target, destination, fail_on_http_error) catch {
    err => {
      if !silent {
        @stdio.stderr.write("curl: \{err}\n")
      }
      failed = true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
