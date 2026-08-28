///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("quiet", short='q'),
    @cli.option("output-document", short='O'),
    @cli.option("output-file", short='o'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("wget: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write("Usage: wget [-q] [-O FILE] URL\n")
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
  let destination = match output_path {
    Some("-") => None
    Some(path) => Some(path)
    None => Some(@path.Path(urls[0]).basename().to_owned())
  }
  @netops.fetch(urls[0], destination, false) catch {
    err => {
      if !quiet {
        match error_path {
          None => @stdio.stderr.write("wget: \{err}\n")
          Some(path) => {
            let output = @fs.open(
              path,
              mode=WriteOnly,
              create_mode=CreateOrTruncate,
            )
            output.write("wget: \{err}\n")
            output.close()
          }
        }
      }
      @sys.exit(1)
      return
    }
  }
}
