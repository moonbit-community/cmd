///|
fn long_spec(specs : ArrayView[OptionSpec], name : String) -> OptionSpec? {
  for spec in specs {
    if spec.name == name {
      return Some(spec)
    }
  }
  None
}

///|
fn short_spec(specs : ArrayView[OptionSpec], short : Char) -> OptionSpec? {
  for spec in specs {
    if spec.short == Some(short) {
      return Some(spec)
    }
  }
  None
}

///|
fn split_long_option(arg : String) -> (String, String?) {
  for index, char in arg {
    if char == '=' {
      return (arg[2:index].to_owned(), Some(arg[index + 1:].to_owned()))
    }
  }
  (arg[2:].to_owned(), None)
}

///|
fn add_occurrence(
  occurrences : Map[String, Array[String?]],
  spec : OptionSpec,
  value : String?,
) -> Unit raise CliError {
  match occurrences.get(spec.name) {
    Some(_) if !spec.repeatable =>
      raise CliError(
        kind=DuplicateOption,
        option=spec.name,
        message="option may not be repeated",
      )
    Some(values) => values.push(value)
    None => occurrences[spec.name] = [value]
  }
}

///|
fn missing_value(spec : OptionSpec) -> CliError {
  CliError(
    kind=MissingOptionValue,
    option=spec.name,
    message="option requires a value",
  )
}

///|
pub fn parse(
  args : ArrayView[String],
  specs : ArrayView[OptionSpec],
) -> ParsedArgs raise CliError {
  let occurrences : Map[String, Array[String?]] = Map([])
  let operands : Array[String] = []
  let mut options = true
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if options && arg == "--" {
      options = false
      index += 1
      continue
    }
    if !options || arg == "-" || !arg.has_prefix("-") {
      operands.push(arg)
      index += 1
      continue
    }
    if arg.has_prefix("--") {
      let (name, attached) = split_long_option(arg)
      guard long_spec(specs, name) is Some(spec) else {
        raise CliError(
          kind=UnknownOption,
          option=name,
          message="unknown option",
        )
      }
      if spec.takes_value {
        let value = match attached {
          Some(value) => value
          None => {
            index += 1
            if index >= args.length() {
              raise missing_value(spec)
            }
            args[index]
          }
        }
        add_occurrence(occurrences, spec, Some(value))
      } else {
        if attached is Some(_) {
          raise CliError(
            kind=UnexpectedOptionValue,
            option=name,
            message="flag does not accept a value",
          )
        }
        add_occurrence(occurrences, spec, None)
      }
      index += 1
      continue
    }
    let cluster = arg[1:]
    let mut offset = 0
    while offset < cluster.length() {
      guard cluster[offset].to_char() is Some(short) else {
        raise CliError(
          kind=UnknownOption,
          option=cluster[offset:offset + 1].to_owned(),
          message="short option is not an ASCII character",
        )
      }
      guard short_spec(specs, short) is Some(spec) else {
        raise CliError(
          kind=UnknownOption,
          option=short.to_string(),
          message="unknown short option",
        )
      }
      if spec.takes_value {
        let remaining = cluster[offset + 1:].to_owned()
        let value = if remaining != "" && spec.allow_attached {
          remaining
        } else {
          index += 1
          if index >= args.length() {
            raise missing_value(spec)
          }
          args[index]
        }
        add_occurrence(occurrences, spec, Some(value))
        offset = cluster.length()
      } else {
        add_occurrence(occurrences, spec, None)
        offset += 1
      }
    }
    index += 1
  }
  { occurrences, operands, }
}
