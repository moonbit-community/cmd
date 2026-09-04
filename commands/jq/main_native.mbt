///|
priv enum InputSource {
  Stdin
  File(String)
}

///|
priv enum QuerySource {
  Inline(String)
  File(String)
}

///|
priv struct CliOptions {
  query : QuerySource
  inputs : Array[InputSource]
  logs : Bool
  raw_output : Bool
  compact_output : Bool
  null_input : Bool
  sort_keys : Bool
  join_output : Bool
  slurp : Bool
  raw_input : Bool
  exit_status : Bool
  indent : Int?
  tab : Bool
  arguments : Map[String, String]
}

///|
priv enum CliParseResult {
  Help
  Error(String)
  Run(CliOptions)
}

///|
priv suberror ArgError {
  ArgError(String)
}

///|
fn help_message() -> String {
  "Usage: jq [-CjcnrRsM] [-f FILTER_FILE] [--arg NAME VALUE] [--argjson NAME JSON] [FILTER] [FILE...]"
}

///|
fn json_string_literal(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn substitute_arguments(
  query : String,
  arguments : Map[String, String],
) -> String {
  if arguments.is_empty() {
    return query
  }
  let chars : Array[Char] = query.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  let mut quoted = false
  while index < chars.length() {
    let char = chars[index]
    if char == '"' && (index == 0 || chars[index - 1] != '\\') {
      quoted = !quoted
      output.write_char(char)
      index += 1
      continue
    }
    if !quoted && char == '$' && index + 1 < chars.length() {
      let mut end = index + 1
      while end < chars.length() &&
            chars[end] is ('a'..='z' | 'A'..='Z' | '_' | '0'..='9') {
        end += 1
      }
      if end > index + 1 {
        let name = String::from_array(chars[index + 1:end])
        if arguments.get(name) is Some(value) {
          output.write_string(value)
          index = end
          continue
        }
      }
    }
    output.write_char(char)
    index += 1
  }
  output.to_string()
}

///|
fn sort_json(value : Json) -> Json {
  match value {
    Object(fields) => {
      let entries = fields.to_array()
      entries.sort_by((left, right) => left.0.lexical_compare(right.0))
      let sorted : Map[String, Json] = Map([])
      for entry in entries {
        let key = entry.0
        sorted[key] = sort_json(entry.1)
      }
      Json::Json(sorted)
    }
    Array(items) => Json::Json(items.map(sort_json))
    other => other
  }
}

///|
fn indent_json(value : Json, indent : Int, tab : Bool) -> String {
  let rendered = value.stringify(indent~)
  if !tab || indent == 0 {
    return rendered
  }
  let output = StringBuilder()
  for line in rendered.split("\n") {
    let mut index = 0
    while index < line.length() && line[index] == ' ' {
      index += 1
    }
    let tabs = index / indent
    for _ in 0..<tabs {
      output.write_char('\t')
    }
    output.write_string(line[index:].to_owned())
    output.write_char('\n')
  }
  let result = output.to_string()
  if result.has_suffix("\n") {
    result[:result.length() - 1].to_owned()
  } else {
    result
  }
}

///|
fn prepare_args(args : ArrayView[String]) -> Array[String] raise ArgError {
  let prepared : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "--arg" || arg == "--argjson" {
      if index + 2 >= args.length() {
        raise ArgError("{arg} requires NAME and VALUE")
      }
      prepared.push(arg + "=" + args[index + 1] + "\u{0}" + args[index + 2])
      index += 3
    } else {
      prepared.push(arg)
      index += 1
    }
  }
  prepared
}

///|
fn parse_cli(args : ArrayView[String]) -> CliParseResult {
  let normalized = prepare_args(args) catch {
    ArgError(message) =>
      return Error("jq: argument preparation failed: \{message}")
  }
  let parsed = @cli.parse(normalized, [
    @cli.flag("compact-output", short='c'),
    @cli.flag("join-output", short='j'),
    @cli.flag("logs", short='l'),
    @cli.flag("null-input", short='n'),
    @cli.flag("slurp", short='s'),
    @cli.flag("raw-output", short='r'),
    @cli.flag("raw-input", short='R'),
    @cli.flag("sort-keys", short='S'),
    @cli.flag("exit-status", short='e'),
    @cli.flag("color-output", short='C'),
    @cli.flag("monochrome-output", short='M'),
    @cli.option("from-file", short='f'),
    @cli.option("indent"),
    @cli.flag("tab"),
    @cli.option("arg"),
    @cli.option("argjson"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) =>
      return Error("jq: \{message}: '\{option}'\n\{help_message()}")
  }
  if parsed.contains("help") {
    return Help
  }
  if parsed.contains("logs") && parsed.contains("null-input") {
    return Error(
      "jq: logs and null-input are mutually exclusive\n\{help_message()}",
    )
  }
  if parsed.contains("logs") && parsed.contains("raw-input") {
    return Error(
      "jq: logs and raw-input are mutually exclusive\n{help_message()}",
    )
  }
  let indent = match parsed.last_value("indent") {
    Some(value) => {
      let parsed_indent = @string.parse_int(value) catch {
        _ => return Error("jq: invalid indentation: '{value}'")
      }
      if parsed_indent < 0 {
        Some(2)
      } else if parsed_indent > 64 {
        return Error("jq: indentation must be between 0 and 64")
      } else {
        Some(parsed_indent)
      }
    }
    None => None
  }
  let arguments : Map[String, String] = Map([])
  for value in parsed.values("arg") {
    let parts : Array[String] = value
      .split("\u{0}")
      .map(item => item.to_owned())
      .collect()
    if parts.length() != 2 || parts[0] == "" {
      return Error("jq: --arg requires NAME and VALUE")
    }
    arguments[parts[0]] = json_string_literal(parts[1])
  }
  for value in parsed.values("argjson") {
    let parts : Array[String] = value
      .split("\u{0}")
      .map(item => item.to_owned())
      .collect()
    if parts.length() != 2 || parts[0] == "" {
      return Error("jq: --argjson requires NAME and JSON")
    }
    ignore(@json.parse(parts[1])) catch {
      _ => return Error("jq: invalid JSON text passed to --argjson")
    }
    arguments[parts[0]] = parts[1]
  }
  let positionals = parsed.operands
  let filter_files = parsed.values("from-file")
  let query = match filter_files.length() {
    0 => {
      if positionals.is_empty() {
        return Error("error: missing filter\n\n" + help_message())
      }
      QuerySource::Inline(positionals[0])
    }
    1 => File(filter_files[0])
    _ => return Error("error: multiple filters provided\n\n" + help_message())
  }
  let input_start = if filter_files.is_empty() { 1 } else { 0 }
  let inputs : Array[InputSource] = []
  for index in input_start..<positionals.length() {
    let path = positionals[index]
    if path == "-" {
      inputs.push(Stdin)
    } else {
      inputs.push(File(path))
    }
  }
  if inputs.is_empty() && !parsed.contains("null-input") {
    inputs.push(Stdin)
  }
  Run({
    query,
    inputs,
    logs: parsed.contains("logs"),
    raw_output: parsed.contains("raw-output"),
    compact_output: parsed.contains("compact-output"),
    null_input: parsed.contains("null-input"),
    sort_keys: parsed.contains("sort-keys"),
    join_output: parsed.contains("join-output"),
    slurp: parsed.contains("slurp"),
    raw_input: parsed.contains("raw-input"),
    exit_status: parsed.contains("exit-status"),
    indent,
    tab: parsed.contains("tab"),
    arguments,
  })
}

///|
fn read_query(source : QuerySource) -> String raise {
  match source {
    Inline(text) => text
    File(path) => @fs.read_file_to_string(path)
  }
}

///|
async fn read_input(source : InputSource) -> String {
  match source {
    Stdin => @stdio.stdin.read_all().text()
    File(path) => @fs.read_file_to_string(path)
  }
}

///|
fn run_query(
  query : @moonjq.Query,
  input : String,
  logs : Bool,
) -> Iter[Json] raise {
  if logs {
    query.eval_logs(input)
  } else {
    let json = @json.parse(input)
    query.eval(json)
  }
}

///|
fn raw_values(input : String) -> Array[Json] {
  let values : Array[Json] = []
  let lines : Array[String] = input
    .split("\n")
    .map(line => line.to_owned())
    .collect()
  for index, line in lines {
    if index + 1 == lines.length() && line == "" {
      continue
    }
    values.push(Json::string(line))
  }
  values
}

///|
fn render_result(
  value : Json,
  raw_output : Bool,
  compact_output : Bool,
  sort_keys : Bool,
  indent : Int?,
  tab : Bool,
) -> String {
  let value = if sort_keys { sort_json(value) } else { value }
  let spacing = match indent {
    Some(value) => value
    None => if compact_output { 0 } else { 2 }
  }
  if raw_output {
    match value {
      String(text) => text
      _ => indent_json(value, spacing, tab)
    }
  } else {
    indent_json(value, spacing, tab)
  }
}

///|
async fn write_results(
  results : Iter[Json],
  raw_output : Bool,
  compact_output : Bool,
  join_output : Bool,
  sort_keys : Bool,
  indent : Int?,
  tab : Bool,
) -> Unit {
  let rendered : Array[String] = []
  for value in results {
    rendered.push(
      render_result(value, raw_output, compact_output, sort_keys, indent, tab),
    )
  }
  for index, value in rendered {
    @stdio.stdout.write(value)
    if !join_output || index + 1 < rendered.length() {
      @stdio.stdout.write(if join_output { "" } else { "\n" })
    }
  }
}

///|
fn status_for_results(values : Array[Json]) -> Int {
  match values.last() {
    None => 4
    Some(False | Null) => 1
    Some(_) => 0
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  match parse_cli(args) {
    Help => {
      @stdio.stdout.write(help_message() + "\n")
      return
    }
    Error(msg) => {
      @stdio.stderr.write(msg)
      if !msg.has_suffix("\n") {
        @stdio.stderr.write("\n")
      }
      @sys.exit(2)
      return
    }
    Run(options) => {
      let query_text = read_query(options.query) catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(2)
          return
        }
      }
      let query = @moonjq.parse(
        substitute_arguments(query_text, options.arguments),
      ) catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(3)
          return
        }
      }
      try {
        if options.null_input {
          let results = query.eval(null).collect()
          write_results(
            results.iter(),
            options.raw_output,
            options.compact_output,
            options.join_output,
            options.sort_keys,
            options.indent,
            options.tab,
          )
          if options.exit_status {
            @sys.exit(status_for_results(results))
          }
        } else if options.slurp {
          let all : Array[Json] = []
          for input_source in options.inputs {
            let input = read_input(input_source)
            if options.raw_input {
              all.push(Json::Json(input))
            } else if options.logs {
              for value in query.eval_logs(input) {
                all.push(value)
              }
            } else {
              all.push(@json.parse(input))
            }
          }
          let results = query.eval(Json::array(all)).collect()
          write_results(
            results.iter(),
            options.raw_output,
            options.compact_output,
            options.join_output,
            options.sort_keys,
            options.indent,
            options.tab,
          )
          if options.exit_status {
            @sys.exit(status_for_results(results))
          }
        } else if options.raw_input {
          let results : Array[Json] = []
          for input_source in options.inputs {
            let input = read_input(input_source)
            for value in raw_values(input) {
              for result in query.eval(value) {
                results.push(result)
              }
            }
          }
          write_results(
            results.iter(),
            options.raw_output,
            options.compact_output,
            options.join_output,
            options.sort_keys,
            options.indent,
            options.tab,
          )
          if options.exit_status {
            @sys.exit(status_for_results(results))
          }
        } else {
          let results : Array[Json] = []
          for input_source in options.inputs {
            let input = read_input(input_source)
            for result in run_query(query, input, options.logs) {
              results.push(result)
            }
          }
          write_results(
            results.iter(),
            options.raw_output,
            options.compact_output,
            options.join_output,
            options.sort_keys,
            options.indent,
            options.tab,
          )
          if options.exit_status {
            @sys.exit(status_for_results(results))
          }
        }
      } catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(5)
          return
        }
      }
    }
  }
}
