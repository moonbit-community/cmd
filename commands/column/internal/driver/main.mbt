///|
fn help_message() -> String {
  let help = metadata_help()
  help
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.text.write("column \{MODULE_VERSION}\n")
    return
  }
  let parsed = @cli.parse(@env.args()[1:], option_specs()) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("column: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.text.write(help_message())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("column \{MODULE_VERSION}\n")
    return
  }
  let separator = parsed.last_value("separator")
  if separator is Some(value) && value.iter().any(c => c.to_int() >= 128) {
    @stdio.stderr.text.write("column: unsupported non-ASCII input separator\n")
    @env.exit(2)
    return
  }
  let default_width = @string.parse_int(
    @env.get_env_var("COLUMNS").unwrap_or("80"),
  ) catch {
    _ => 80
  }
  let width = match parsed.last_value("output-width") {
    None => if default_width > 0 { default_width } else { 80 }
    Some("unlimited") => 0
    Some(value) => @string.parse_int(value) catch { _ => -1 }
  }
  if width < 0 {
    @stdio.stderr.text.write("column: invalid output width\n")
    @env.exit(1)
    return
  }
  let failed = run_layout(
    parsed.operands,
    table=parsed.contains("table"),
    separator~,
    output_separator=parsed
      .last_value("output-separator")
      .unwrap_or(DEFAULT_OUTPUT_SEPARATOR),
    width~,
    fill_rows=parsed.contains("fillrows"),
  ) catch {
    err => {
      @stdio.stderr.text.write("column: \{@stream.transport_cause(err)}\n")
      true
    }
  }
  if failed {
    @env.exit(1)
  }
}
