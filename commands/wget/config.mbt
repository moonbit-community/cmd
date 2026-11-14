///|
suberror ConfigError {
  ConfigError(Int32, String)
}

///|
fn config_name(name : String) -> String {
  name.to_lower().replace_all(old="-", new="").replace_all(old="_", new="")
}

///|
fn config_setting(raw : String) -> Array[String] raise UsageError {
  let args : Array[String] = []
  let specs = option_specs()
  let line = raw[:raw.find("\u0000").unwrap_or(raw.length())].trim(
    chars=" \t\r\n\u000b\u000c",
  )
  if line.is_empty() || line.has_prefix("#") {
    return []
  }
  guard line.split_once("=") is Some((key, value)) else {
    raise UsageError("invalid config line: " + line.to_owned())
  }
  let name = config_name(key.trim().to_owned())
  let mut value = value.trim(chars=" \t\r\n\u000b\u000c").to_owned()
  let canonical = match name {
    "checkcertificate" => "check-certificate"
    "useproxy" => "proxy"
    "logfile" => "output-file"
    "input" => "input-file"
    _ => {
      guard specs
        .iter()
        .find_first(spec => {
          !spec.name.has_prefix("no-") && config_name(spec.name) == name
        })
        is Some(spec) else {
        raise UsageError("unsupported config setting: " + key.to_owned())
      }
      spec.name
    }
  }
  if ["config", "no-config", "execute", "help"].contains(canonical) {
    raise UsageError("unsupported config setting: " + key.to_owned())
  }
  let spec = specs.iter().find_first(spec => spec.name == canonical).unwrap()
  if canonical == "tries" || canonical == "max-redirect" {
    value = config_number(key.trim().to_owned(), value).to_string()
  }
  if !spec.takes_value {
    let enabled = match value.to_lower() {
      "on" | "yes" | "1" => true
      "off" | "no" | "0" => false
      _ => raise UsageError("invalid config boolean: " + value)
    }
    args.push("--" + (if enabled { canonical } else { "no-" + canonical }))
  } else if canonical == "auth-no-challenge" {
    args.push("--auth-no-challenge=" + value)
  } else {
    args.append(["--" + canonical, value])
  }
  ignore(parse_options(args))
  args
}

///|
fn config_number(name : String, value : String) -> Int32 raise UsageError {
  let mut position = 0
  let negative = value.has_prefix("-")
  if negative || value.has_prefix("+") {
    position = 1
  }
  let mut number = 0L
  while position < value.length() {
    let digit = value.code_unit_at(position).to_int() - 48
    if digit < 0 || digit > 9 {
      break
    }
    number = number * 10L + digit.to_int64()
    if number > 2147483647L {
      raise UsageError(name + ": Invalid number '" + value + "'.")
    }
    position += 1
  }
  if negative && number > 0L {
    raise UsageError(name + ": Invalid number '" + value + "'.")
  }
  number.to_int()
}

///|
fn config_file_arguments(text : String, path : String) -> Array[String] raise {
  let args : Array[String] = []
  let errors : Array[String] = []
  for index, raw in text.split("\n").to_array() {
    let parsed = config_setting(raw.to_owned()) catch {
      UsageError(message) => {
        errors.append([
          "wget: " + message,
          "wget: Error in " + path + " at line " + (index + 1).to_string() + ".",
        ])
        continue
      }
    }
    args.append(parsed)
  }
  if !errors.is_empty() {
    errors.push("Exiting due to error in " + path)
    raise ConfigError(
      2,
      errors.join("\n").strip_prefix("wget: ").unwrap().to_owned(),
    )
  }
  args
}

///|
fn execute_arguments(text : String) -> Array[String] raise UsageError {
  let args = config_setting(text)
  if args.is_empty() {
    raise UsageError("Invalid --execute command '" + text + "'")
  }
  args
}

///|
fn config_tokens(
  args : ArrayView[String],
) -> Array[(String, String?)] raise UsageError {
  let specs = option_specs()
  let output : Array[(String, String?)] = []
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    index += 1
    if arg == "--" {
      output.push((arg, None))
      for value in args[index:] {
        output.push((value, None))
      }
      break
    }
    let tokens : Array[(String, String?)] = []
    if arg.has_prefix("--") {
      match arg.split_once("=") {
        Some((key, value)) =>
          tokens.push((key.to_owned(), Some(value.to_owned())))
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
      tokens.push((arg, None))
    }
    for (name, attached) in tokens {
      let takes_value = specs.any(spec => {
        spec.takes_value &&
        (
          name == "--" + spec.name ||
          spec.short.map(char => "-" + char.to_string()) == Some(name)
        )
      })
      let value = if takes_value &&
        attached is None &&
        name != "--auth-no-challenge" {
        guard args.get(index) is Some(value) else {
          raise UsageError(name + " requires an argument")
        }
        index += 1
        Some(value)
      } else {
        attached
      }
      output.push((name, value))
    }
  }
  output
}

///|
async fn configured_arguments(args : ArrayView[String]) -> Array[String] {
  let tokens = config_tokens(args)
  let output : Array[String] = []
  let mut selected = false
  for (name, value) in tokens {
    if name == "--" {
      break
    }
    if name == "--no-config" {
      selected = true
      break
    }
    if name == "--config" {
      let path = value.unwrap()
      let text = @fs.read_file(path).text() catch {
        _ => raise ConfigError(2, "cannot read config from '" + path + "'")
      }
      output.append(config_file_arguments(text, path))
      selected = true
      break
    }
  }
  if !selected {
    let system = @env.get_env_var("SYSTEM_WGETRC").unwrap_or("/etc/wgetrc")
    let system_text = Some(@fs.read_file(system).text()) catch { _ => None }
    if system_text is Some(text) {
      output.append(config_file_arguments(text, system))
    }
    let path = match @env.get_env_var("WGETRC") {
      Some(path) if path != "" => Some((path, true))
      _ =>
        @env.get_env_var("HOME").map(directory => {
          (directory + "/.wgetrc", false)
        })
    }
    if path is Some((path, required)) {
      let text = @fs.read_file(path).text() catch {
        _ =>
          if required {
            raise ConfigError(1, "cannot read WGETRC from '" + path + "'")
          } else {
            ""
          }
      }
      output.append(config_file_arguments(text, path))
    }
  }
  let mut literal = false
  for (name, value) in tokens {
    if name == "--" {
      literal = true
    }
    if !literal && name == "--no-config" {
      if value is Some(value) &&
        !["on", "off", "yes", "no", "1", "0"].contains(value.to_lower()) {
        raise UsageError(
          "--no-config: Invalid boolean '" + value + "'; use `on' or `off'.",
        )
      }
      continue
    }
    if !literal && name == "--config" {
      continue
    }
    if !literal && (name == "--execute" || name == "-e") {
      output.append(execute_arguments(value.unwrap()))
    } else if value is Some(value) {
      // Attached spelling preserves optional-value and flag diagnostics.
      if name.has_prefix("--") {
        output.push(name + "=" + value)
      } else {
        output.append([name, value])
      }
    } else {
      output.push(name)
    }
  }
  output
}
