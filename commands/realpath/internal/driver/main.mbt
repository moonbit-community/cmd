///|
fn relative_path(path : String, base : String) -> String {
  let result = @path.Path(path).relative(base=@path.Path(base)).to_string()
  if result.is_empty() {
    "."
  } else {
    result
  }
}

///|
pub async fn run_main() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs()) catch {
    @cli.CliError(kind=MissingOptionValue, option~, ..) if option ==
      "relative-to" ||
      option == "relative-base" => {
      @stdio.stderr.write(
        "realpath: option '--\{option}' requires an argument\nTry 'realpath --help' for more information.\n",
      )
      @env.exit(1)
      return
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("realpath: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("realpath \{MODULE_VERSION}\n")
    return
  }
  if parsed.operands.is_empty() {
    @stdio.stderr.write(
      "realpath: missing operand\nTry 'realpath --help' for more information.\n",
    )
    @env.exit(1)
    return
  }
  let existence = match
    parsed.last_occurrence([
      "canonicalize-existing", "canonicalize-missing", "canonicalize",
    ]) {
    Some("canonicalize-existing") => @pathresolve.Existing
    Some("canonicalize-missing") => @pathresolve.Missing
    _ => @pathresolve.AllButLast
  }
  let strip = parsed.contains("strip") || parsed.contains("no-symlinks")
  let base_arg = parsed.last_value("relative-base")
  let to_arg = match parsed.last_value("relative-to") {
    Some(_) as value => value
    None => base_arg
  }
  let mut relative_to : String? = None
  let mut relative_base : String? = None
  for (argument, is_base) in [(to_arg, false), (base_arg, true)] {
    if argument is Some(argument) {
      let value = @pathresolve.resolve_path(argument, existence, strip) catch {
        @pathresolve.ReadlinkBoundary(_) => {
          @stdio.stderr.write(
            "realpath: unsupported capability: unresolved symbolic-link target (readlink)\n",
          )
          @env.exit(2)
          return
        }
        error => {
          @stdio.stderr.write(
            "realpath: \{argument}: \{@pathresolve.error_text(error)}\n",
          )
          @env.exit(1)
          return
        }
      }
      if existence is Existing && !(@fs.kind(value) is Directory) {
        @stdio.stderr.write("realpath: \{argument}: Not a directory\n")
        @env.exit(1)
        return
      }
      if is_base {
        relative_base = Some(value)
      } else {
        relative_to = Some(value)
      }
    }
  }
  if relative_base is Some(base) &&
    relative_to is Some(to) &&
    !@pathresolve.inside(to, base) {
    relative_to = None
  }
  let separator = if parsed.contains("zero") { "\u0000" } else { "\n" }
  let mut status = 0
  for operand in parsed.operands {
    let value = @pathresolve.resolve_path(operand, existence, strip) catch {
      @pathresolve.ReadlinkBoundary(_) => {
        if !parsed.contains("quiet") {
          @stdio.stderr.write(
            "realpath: unsupported capability: unresolved symbolic-link target (readlink)\n",
          )
        }
        status = 2
        continue
      }
      error => {
        if !parsed.contains("quiet") {
          @stdio.stderr.write(
            "realpath: \{operand}: \{@pathresolve.error_text(error)}\n",
          )
        }
        status = status.max(1)
        continue
      }
    }
    let relative = relative_base
      .map(base => @pathresolve.inside(value, base))
      .unwrap_or(true)
    let output = if relative && relative_to is Some(to) {
      relative_path(value, to)
    } else {
      value
    }
    @stdio.stdout.write(output + separator)
  }
  if status != 0 {
    @env.exit(status)
  }
}
