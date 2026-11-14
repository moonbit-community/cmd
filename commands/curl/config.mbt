///|
const MaxConfigDepth = 5

///|
suberror OptionConflict {
  OptionConflict(String)
}

///|
suberror ConfigLineError {
  ConfigLineError(String, String)
}

///|
suberror ConfigOptionError {
  ConfigOptionError(String, String)
}

///|
const MaxConfigLineBytes = 10485760

///|
fn config_arguments(text : String) -> Array[String] raise {
  let args : Array[String] = []
  for raw in text.split("\n") {
    if @utf8.encode(raw.to_owned()).length() >= MaxConfigLineBytes {
      raise UsageError("config line exceeds 10485760 bytes")
    }
    let line = raw.trim_start(chars=" \t").to_owned()
    if line == "" || line.has_prefix("#") {
      continue
    }
    let offset = args.length()
    let dashed = line.has_prefix("-")
    let mut end = 0
    while end < line.length() {
      let character = line.code_unit_at(end)
      if character == ' ' ||
        character == '\t' ||
        (!dashed && (character == '=' || character == ':')) {
        break
      }
      end += 1
    }
    let name = line[:end].to_owned()
    args.push(if dashed { name } else { "--" + name })
    let mut start = end
    while start < line.length() {
      let character = line.code_unit_at(start)
      if character == ' ' ||
        character == '\t' ||
        (!dashed && (character == '=' || character == ':')) {
        start += 1
      } else {
        break
      }
    }
    if start < line.length() && line.code_unit_at(start) == '"' {
      let value = StringBuilder()
      let mut escaped = false
      for character in line[start + 1:] {
        if escaped {
          value.write_char(
            match character {
              'n' => '\n'
              'r' => '\r'
              't' => '\t'
              'v' => '\u000b'
              other => other
            },
          )
          escaped = false
        } else if character == '\\' {
          escaped = true
        } else if character == '"' {
          break
        } else {
          value.write_char(character)
        }
      }
      args.push(value.to_string())
    } else {
      let mut end = start
      while end < line.length() &&
            ![' ', '\t', '\r', '\n', '\u000b', '\u000c'].contains(
              line.code_unit_at(end).to_int().to_char().unwrap(),
            ) {
        end += 1
      }
      if end > start {
        args.push(line[start:end].to_owned())
      }
    }
    let specs = option_specs()
    let flag = specs.any(spec => {
      !spec.takes_value &&
      (
        args[offset] == "--" + spec.name ||
        spec.short.map(short => "-" + short.to_string()) == Some(args[offset])
      )
    })
    if flag && args.length() == offset + 2 && args[offset + 1] == "" {
      ignore(args.pop())
    }
    let parsed = @cli.parse(args[offset:], specs) catch {
      @cli.CliError(kind~, ..) =>
        raise ConfigLineError(
          name,
          match kind {
            UnknownOption => "is unknown"
            MissingOptionValue => "requires parameter"
            _ => "is badly used here"
          },
        )
    }
    if !parsed.operands.is_empty() {
      raise ConfigLineError(name, "had unsupported trailing garbage")
    }
    if parsed.order.any(name => {
        specs.any(spec => spec.name == name && spec.takes_value)
      }) &&
      !parsed
      .last_value("header")
      .map(value => value.has_prefix("@"))
      .unwrap_or(false) {
      ignore(parse_options(args[offset:])) catch {
        UsageError(_) =>
          raise ConfigLineError(
            name,
            if parsed.order.any(name => {
                [
                  "retry", "retry-delay", "retry-max-time", "max-redirs", "connect-timeout",
                  "max-time", "idle-timeout",
                ].contains(name)
              }) {
              "expected a proper numerical parameter"
            } else {
              "is badly used here"
            },
          )
      }
    }
  }
  args
}

///|
async fn config_text(path : String) -> String {
  if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
}

///|
async fn config_file_into(
  output : Array[String],
  text : String,
  path : String,
  read : async (String) -> String,
  depth : Int32,
  file_headers~ : Set[Int32],
) -> Unit {
  for index, line in text.split("\n").to_array() {
    let args = config_arguments(line.to_owned()) catch {
      ConfigLineError(option, reason) => {
        let parsed = try @cli.parse(output, option_specs()) catch {
          _ => None
        } noraise {
          parsed => Some(parsed)
        }
        let silent = parsed
          .map(parsed => enabled(parsed, "silent"))
          .unwrap_or(false)
        if !silent ||
          parsed.map(parsed => enabled(parsed, "show-error")).unwrap_or(false) {
          config_diagnostic(
            (if path == "-" { "<stdin>" } else { path }) +
            ":" +
            (index + 1).to_string() +
            " config file option '" +
            option +
            "' " +
            reason,
          )
        }
        raise ConfigOptionError(
          "--config",
          if reason == "is unknown" {
            "found an unknown config option"
          } else {
            reason
          },
        )
      }
      error => raise error
    }
    expand_config_into(output, args, read, depth, file_headers~) catch {
      ConfigOptionError(option, reason) as error => {
        config_report(
          output,
          (if path == "-" { "<stdin>" } else { path }) +
          ":" +
          (index + 1).to_string() +
          " config file option '" +
          option.trim_start(chars="-").to_owned() +
          "' " +
          reason,
        )
        if reason == "error encountered when reading a file" {
          config_report(output, "cannot read config from '" + path + "'")
        }
        raise error
      }
      error => raise error
    }
  }
}

///|
async fn config_report(output : Array[String], message : String) -> Unit {
  let parsed = try @cli.parse(output, option_specs()) catch {
    _ => None
  } noraise {
    parsed => Some(parsed)
  }
  if !parsed.map(parsed => enabled(parsed, "silent")).unwrap_or(false) ||
    parsed.map(parsed => enabled(parsed, "show-error")).unwrap_or(false) {
    config_diagnostic(message)
  }
}

///|
async fn config_diagnostic(message : String) -> Unit {
  // Curl's non-terminal diagnostic width is 79 bytes including its prefix.
  let bytes = @utf8.encode(message)
  let width = 73
  let mut offset = 0
  while offset < bytes.length() {
    let mut count = (bytes.length() - offset).min(width)
    if bytes.length() - offset > width {
      let mut cut = width - 1
      while cut > 0 &&
            bytes[offset + cut] != b' ' &&
            bytes[offset + cut] != b'\t' {
        cut -= 1
      }
      if cut > 0 {
        count = cut + 1
      }
    }
    @stdio.stderr.write(
      b"curl: " + bytes[offset:offset + count].to_owned() + b"\n",
    )
    offset += count
  }
}

///|
async fn expand_config_into(
  output : Array[String],
  args : ArrayView[String],
  read : async (String) -> String,
  depth : Int32,
  file_headers~ : Set[Int32] = Set([]),
) -> Unit {
  let specs = option_specs()
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    index += 1
    if arg == "--" {
      for value in args[index:] {
        output.append(["--url", value])
      }
      break
    }
    let tokens : Array[(String, String?)] = []
    if arg.has_prefix("--") {
      match arg.split_once("=") {
        Some((name, value)) =>
          tokens.push((name.to_owned(), Some(value.to_owned())))
        None => tokens.push((arg, None))
      }
    } else if arg.has_prefix("-") && arg != "-" {
      let chars = arg.iter().to_array()
      for position = 1; position < chars.length(); position = position + 1 {
        let short = chars[position]
        let name = "-" + short.to_string()
        if specs.any(spec => spec.short == Some(short) && spec.takes_value) {
          tokens.push(
            (
              name,
              if position + 1 < chars.length() {
                Some(String::from_iter(chars[position + 1:].iter()))
              } else {
                None
              },
            ),
          )
          break
        }
        tokens.push((name, None))
      }
    } else {
      // Keeping URLs as options preserves their order across included files.
      output.append(["--url", arg])
      continue
    }
    for (name, attached) in tokens {
      let spec = specs
        .iter()
        .find_first(spec => {
          name == "--" + spec.name ||
          spec.short.map(char => "-" + char.to_string()) == Some(name)
        })
      guard spec is Some(spec) else {
        raise UsageError("unrecognized option: '" + name + "'")
      }
      let takes_value = spec.takes_value
      let value = if takes_value && attached is None {
        guard args.get(index) is Some(value) else {
          raise UsageError(name + " requires an argument")
        }
        index += 1
        Some(value)
      } else {
        attached
      }
      let current = if !takes_value && attached is Some(value) {
        [name + "=" + value]
      } else if value is Some(value) {
        [name, value]
      } else {
        [name]
      }
      ignore(@cli.parse(current, specs)) catch {
        @cli.CliError(message~, option~, ..) =>
          raise UsageError("\{message}: '\{option}'")
      }
      if spec.name == "head" || spec.name == "no-head" {
        let previous = @cli.parse(output, specs)
        let opposite = if spec.name == "head" { "no-head" } else { "head" }
        if previous.contains(opposite) {
          raise OptionConflict("--" + spec.name)
        }
      }
      // Validate each value before a later option can read a file or stdin.
      // Cross-option constraints still belong to the final option assembly.
      if takes_value &&
        spec.name != "config" &&
        !(spec.name == "header" && value.unwrap().has_prefix("@")) {
        ignore(parse_options(current))
      }
      if (name == "--header" || name == "-H") &&
        value is Some(value) &&
        value.has_prefix("@") {
        let path = value[1:].to_owned()
        let text = read(path) catch {
          _ => {
            config_report(output, "Failed to open " + path)
            raise ConfigOptionError(
              name, "error encountered when reading a file",
            )
          }
        }
        for raw in text.split("\n") {
          let line = raw.trim_start(chars=" \t").to_owned()
          if line == "" || line.has_prefix("#") {
            continue
          }
          if @utf8.encode(raw.to_owned()).length() >= 102400 {
            raise ConfigOptionError(
              name, "error encountered when reading a file",
            )
          }
          let parsed = @cli.parse(output, option_specs())
          file_headers.add(parsed.values("header").length())
          output.append(["--header", line])
        }
      } else if name == "--config" || name == "-K" {
        guard depth < MaxConfigDepth else {
          config_report(
            output,
            "Max config file recursion level reached (" +
            MaxConfigDepth.to_string() +
            ")",
          )
          raise ConfigOptionError(name, "is badly used here")
        }
        let path = value.unwrap()
        let text = read(path) catch {
          _ => {
            config_report(output, "cannot read config from '" + path + "'")
            raise ConfigOptionError(
              name, "error encountered when reading a file",
            )
          }
        }
        config_file_into(output, text, path, read, depth + 1, file_headers~) catch {
          ConfigOptionError(_, reason) => raise ConfigOptionError(name, reason)
          error => raise error
        }
      } else if !takes_value && attached is Some(value) {
        output.push(name + "=" + value)
      } else {
        output.push(name)
        if value is Some(value) {
          output.push(value)
        }
      }
    }
  }
}

///|
async fn configured_arguments(
  args : ArrayView[String],
  file_headers~ : Set[Int32],
) -> Array[String] {
  let output : Array[String] = []
  let disabled = args.get(0) == Some("--disable") ||
    args.get(0).map(arg => arg.has_prefix("-q")).unwrap_or(false)
  if !disabled {
    let candidates : Array[String] = []
    let locations = [
      ("CURL_HOME", "/.curlrc"),
      ("XDG_CONFIG_HOME", "/curlrc"),
      ("HOME", "/.curlrc"),
    ]
    if @env.get_env_var("XDG_CONFIG_HOME").unwrap_or("") == "" {
      locations.append([
        ("CURL_HOME", "/.config/curlrc"),
        ("HOME", "/.config/curlrc"),
      ])
    }
    for (variable, suffix) in locations {
      if @env.get_env_var(variable) is Some(directory) && directory != "" {
        candidates.push(directory + suffix)
      }
    }
    for path in candidates {
      let text = config_text(path) catch { _ => continue }
      config_file_into(output, text, path, config_text, 0, file_headers~) catch {
        ConfigOptionError(_, _) => ()
        error => raise error
      }
      break
    }
  }
  expand_config_into(output, args, config_text, 0, file_headers~)
  output
}
