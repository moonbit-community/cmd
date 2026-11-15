///|
fn normalized_args(
  args : ArrayView[String],
) -> Array[String] raise @cli.CliError {
  let result : Array[String] = []
  let mut options = true
  let mut value_next = false
  for arg in args {
    if value_next {
      result.push(arg)
      value_next = false
      continue
    }
    if options && arg == "--" {
      options = false
    }
    if options && (arg == "--check-quiet" || arg.has_prefix("--check-quiet=")) {
      raise @cli.CliError(
        kind=UnknownOption,
        option=arg,
        message="unknown option",
      )
    }
    result.push(
      if options && arg == "--check=quiet" {
        "--check-quiet"
      } else {
        arg
      },
    )
    if options {
      if [
          "--key", "--field-separator", "--output", "--random-source", "--sort",
          "--buffer-size", "--temporary-directory", "--batch-size",
        ].contains(arg) {
        value_next = true
      } else if arg.has_prefix("-") && !arg.has_prefix("--") {
        for offset in 1..<arg.length() {
          if arg[offset] is ('k' | 't' | 'o' | 'S' | 'T') {
            value_next = offset + 1 == arg.length()
            break
          }
        }
      }
    }
  }
  result
}

///|
fn parse_args(args : ArrayView[String]) -> @cli.ParsedArgs raise @cli.CliError {
  @cli.parse(normalized_args(args), option_specs())
}

///|
fn one_path(
  parsed : @cli.ParsedArgs,
  name : String,
  label : String,
) -> String? raise CliError {
  let values = parsed.values(name)
  guard values.get(0) is Some(first) else { return None }
  if values.any(value => value != first) {
    raise @order.CliError("sort: multiple \{label} specified")
  }
  Some(first)
}

///|
async fn preflight_sources(sources : Array[String]) -> Unit {
  for source in sources {
    if source != "-" {
      let file = @fs.open(source, mode=ReadOnly) catch {
        @os_error.OSError(_) as error =>
          raise @order.CliError(
            "sort: cannot read: \{source}: \{os_message(error)}",
          )
        error => raise error
      }
      file.close()
    }
  }
}

///|
async fn prepare_output(path : String, merge : Bool) -> Unit {
  let file = @fs.open(
    path,
    mode=WriteOnly,
    create_mode=if merge { CreateNew } else { OpenOrCreate },
  ) catch {
    @os_error.OSError(_) as error if merge && error.is_EEXIST() =>
      raise @order.CliError(
        "sort: unsupported capability: merge into existing output",
      )
    @os_error.OSError(_) as error =>
      raise @order.CliError("sort: open failed: \{path}: \{os_message(error)}")
    error => raise error
  }
  file.close()
}

///|
async fn execute_sort(parsed : @cli.ParsedArgs) -> Int32 {
  let (budget, fan_in) = resource_controls(parsed)
  let output_path = one_path(parsed, "output", "output files")
  let source = one_path(parsed, "random-source", "random sources")
  if parsed.contains("check") && parsed.contains("check-quiet") {
    raise @order.CliError("sort: options '-cC' are incompatible")
  }
  let global = default_modifiers(parsed)
  let separator = match parsed.last_value("field-separator") {
    Some(text) => {
      let bytes = @utf8.encode(text)
      if bytes.length() != 1 {
        raise @order.CliError("sort: the field separator must be a single byte")
      }
      Some(bytes[0])
    }
    None => None
  }
  let specs = parsed.values("key").map(key => @order.parse_key(key, global))
  if specs.is_empty() {
    @order.validate_ordering(global)
  } else {
    for spec in specs {
      @order.validate_ordering(spec.modifiers)
    }
  }
  let need_random = if specs.is_empty() {
    global.mode == Random
  } else {
    specs.any(spec => spec.modifiers.mode == Random)
  }
  let seed = if need_random { random_seed(source) } else { b"" }
  let check = parsed.contains("check") || parsed.contains("check-quiet")
  let check_letter = if parsed.contains("check-quiet") { "C" } else { "c" }
  if check && output_path is Some(_) {
    raise @order.CliError("sort: options '-\{check_letter}o' are incompatible")
  }
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  if check && sources.length() > 1 {
    raise @order.CliError(
      "sort: extra operand '\{sources[1]}' not allowed with -\{check_letter}",
    )
  }
  preflight_sources(sources)
  if output_path is Some(path) {
    prepare_output(path, parsed.contains("merge"))
  }
  sort_sources(
    sources,
    @stdio.stdout,
    if parsed.contains("zero-terminated") {
      b'\x00'
    } else {
      b'\n'
    },
    specs,
    global,
    separator,
    unique=parsed.contains("unique"),
    stable=parsed.contains("stable"),
    merge=parsed.contains("merge"),
    check~,
    diagnose=parsed.contains("check"),
    seed~,
    output_path~,
    budget~,
    fan_in~,
    temporary_directories=parsed.values("temporary-directory"),
  )
}
