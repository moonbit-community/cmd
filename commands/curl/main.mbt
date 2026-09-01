///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("silent", short='s'),
    @cli.flag("show-error", short='S'),
    @cli.flag("fail", short='f'),
    @cli.option("output", short='o'),
    @cli.option("idle-timeout"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("curl: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: curl [-sSf] [-o FILE] [--idle-timeout SECONDS] URL\n",
    )
    return
  }
  let output_path = parsed.last_value("output")
  let fail_on_http_error = parsed.contains("fail")
  let silent = parsed.contains("silent")
  let show_error = !silent || parsed.contains("show-error")
  let timeout_text = parsed.last_value("idle-timeout").unwrap_or("30")
  let idle_timeout_ms = @cli.parse_idle_timeout(timeout_text) catch {
    @cli.CliError(message~, ..) => {
      @stdio.stderr.write("curl: \{message}\n")
      @sys.exit(2)
      return
    }
  }
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
  @netops.fetch_with_options(
    target,
    destination,
    @netops.fetch_options_with_feedback(
      fail_on_http_error,
      idle_timeout_ms,
      if silent {
        if show_error {
          @netops.FeedbackMode::ErrorsOnly
        } else {
          @netops.FeedbackMode::Quiet
        }
      } else {
        @netops.FeedbackMode::Progress
      },
      "curl",
    ),
  ) catch {
    @netops.NetOpError(_) => failed = true
    err => {
      ignore(err)
      failed = true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
