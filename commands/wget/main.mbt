///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("quiet", short='q'),
    @cli.option("output-document", short='O'),
    @cli.option("output-file", short='o'),
    @cli.option("idle-timeout"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("wget: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: wget [-q] [-O FILE] [--idle-timeout SECONDS] URL\n",
    )
    return
  }
  let urls = parsed.operands
  if urls.length() != 1 {
    @stdio.stderr.write("wget: exactly one URL is required\n")
    @sys.exit(2)
    return
  }
  let output_path = parsed.last_value("output-document")
  let error_path = parsed.last_value("output-file")
  let quiet = parsed.contains("quiet")
  let timeout_text = parsed.last_value("idle-timeout").unwrap_or("30")
  let idle_timeout_ms = @cli.parse_idle_timeout(timeout_text) catch {
    @cli.CliError(message~, ..) => {
      @stdio.stderr.write("wget: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  let destination = match output_path {
    Some("-") => None
    Some(path) => Some(path)
    None => Some(@path.Path(urls[0]).basename().to_owned())
  }
  @netops.fetch_with_options(
    urls[0],
    destination,
    @netops.fetch_options_with_feedback(
      true,
      idle_timeout_ms,
      if quiet {
        @netops.FeedbackMode::ErrorsOnly
      } else {
        @netops.FeedbackMode::Progress
      },
      "wget",
      diagnostic_path=error_path,
    ),
  ) catch {
    @netops.NetOpError(_) => {
      @sys.exit(1)
      return
    }
    err => {
      ignore(err)
      @sys.exit(1)
      return
    }
  }
}
