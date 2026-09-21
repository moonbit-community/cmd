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
  color_output : Bool
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
  "Usage: jq [-CjcnrRseSM] [-f FILTER_FILE] [--arg NAME VALUE] [--argjson NAME JSON] [--indent -1..7 | --tab] [FILTER] [FILE...]\n  -C, --color-output       emit ANSI colors (JQ_COLORS customizes the palette)\n  -M, --monochrome-output  disable colors, including when -C is present"
}

///|
fn json_string_literal(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn compile_query(
  query : String,
  arguments : Map[String, String],
) -> @ast.Expr raise {
  let mut expr = @moonjq.parse(query).expr
  for name, value in arguments {
    expr = @ast.Expr::As(@moonjq.parse(value).expr, name, expr)
  }
  expr
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
fn prepare_args(args : ArrayView[String]) -> Array[String] raise ArgError {
  let prepared : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "--arg" || arg == "--argjson" {
      if index + 2 >= args.length() {
        raise ArgError("\{arg} requires NAME and VALUE")
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
      "jq: logs and raw-input are mutually exclusive\n\{help_message()}",
    )
  }
  let mut indent = 2
  let mut tab = false
  let mut compact_output = false
  let indent_values = parsed.values("indent")
  let mut indent_index = 0
  for option in parsed.order {
    match option {
      "compact-output" => {
        compact_output = true
        tab = false
      }
      "tab" => {
        compact_output = false
        tab = true
      }
      "indent" => {
        let value = indent_values[indent_index]
        indent_index += 1
        let spaces = @string.parse_int(value) catch {
          _ => return Error("jq: indentation must be between -1 and 7")
        }
        if spaces < -1 || spaces > 7 || value.trim() != value {
          return Error("jq: indentation must be between -1 and 7")
        }
        // jq 1.8.2 uses tabs for -1 and keeps line breaks for zero spaces.
        compact_output = false
        indent = spaces.max(0)
        tab = spaces == -1
      }
      _ => ()
    }
  }
  let arguments : Map[String, String] = Map([])
  let string_args = parsed.values("arg")
  let json_args = parsed.values("argjson")
  let mut string_index = 0
  let mut json_index = 0
  for option in parsed.order {
    if option != "arg" && option != "argjson" {
      continue
    }
    let value = if option == "arg" {
      let value = string_args[string_index]
      string_index += 1
      value
    } else {
      let value = json_args[json_index]
      json_index += 1
      value
    }
    let parts : Array[String] = value
      .split("\u{0}")
      .map(item => item.to_owned())
      .collect()
    if parts.length() != 2 || parts[0] == "" {
      return Error("jq: --\{option} requires NAME and VALUE")
    }
    if option == "arg" {
      arguments[parts[0]] = json_string_literal(parts[1])
    } else {
      ignore(@json.parse(parts[1])) catch {
        _ =>
          return Error(
            "jq: invalid JSON text passed to --argjson\nUse jq --help for help with command-line options,\nor see the jq manpage, or online docs at https://jqlang.org",
          )
      }
      arguments[parts[0]] = parts[1]
    }
  }
  let positionals = parsed.operands
  let filter_files = parsed.values("from-file")
  let query = match filter_files.length() {
    0 => QuerySource::Inline(positionals.get(0).unwrap_or("."))
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
    compact_output,
    null_input: parsed.contains("null-input"),
    sort_keys: parsed.contains("sort-keys"),
    join_output: parsed.contains("join-output"),
    slurp: parsed.contains("slurp"),
    raw_input: parsed.contains("raw-input"),
    exit_status: parsed.contains("exit-status"),
    color_output: parsed.contains("color-output") &&
    !parsed.contains("monochrome-output"),
    indent: Some(indent),
    tab,
    arguments,
  })
}

///|
async fn read_query(source : QuerySource) -> String {
  match source {
    Inline(text) => text
    File(path) => @fs.read_file(path).text()
  }
}

///|
fn render_result(
  value : Json,
  raw_output : Bool,
  compact_output : Bool,
  sort_keys : Bool,
  indent : Int?,
  tab : Bool,
  colors : Array[String]?,
) -> String {
  let value = if sort_keys { sort_json(value) } else { value }
  let spacing = match indent {
    Some(value) => value
    None => if compact_output { 0 } else { 2 }
  }
  if raw_output {
    match value {
      String(text) => text
      _ => render_json(value, !compact_output, spacing, tab, colors)
    }
  } else {
    render_json(value, !compact_output, spacing, tab, colors)
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
  colors : Array[String]?,
) -> Json? {
  let mut last : Json? = None
  for value in results {
    @stdio.stdout.write(
      render_result(
        value, raw_output, compact_output, sort_keys, indent, tab, colors,
      ),
    )
    if !join_output {
      @stdio.stdout.write("\n")
    }
    last = Some(value)
  }
  last
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
      let (palette, valid_colors) = parse_colors(@env.get_env_var("JQ_COLORS"))
      if !valid_colors {
        @stdio.stderr.write("Failed to set $JQ_COLORS\n")
      }
      let query_text = read_query(options.query) catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(2)
          return
        }
      }
      let query = compile_query(query_text, options.arguments) catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(3)
          return
        }
      }
      try {
        let state : Evaluation = {
          query,
          options,
          colors: if options.color_output {
            Some(palette)
          } else {
            None
          },
          last: None,
          values: [],
          raw: [],
        }
        if options.null_input {
          state.emit(Json::null())
        } else {
          for source in options.inputs {
            match source {
              Stdin => state.read(@stdio.stdin)
              File(path) => {
                let file = @fs.open(path, mode=ReadOnly)
                defer file.close()
                state.read(file)
              }
            }
          }
          if options.slurp {
            state.emit(
              if options.raw_input {
                Json::string(@utf8.decode(Bytes::from_array(state.raw)))
              } else {
                Json::array(state.values)
              },
            )
          }
        }
        if options.exit_status {
          @sys.exit(
            status_for_results(
              match state.last {
                None => []
                Some(value) => [value]
              },
            ),
          )
        }
      } catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(
            match err {
              @json.InvalidChar(_, _)
              | @json.InvalidEof
              | @json.InvalidNumber(_, _)
              | @json.InvalidIdentEscape(_)
              | @json.DepthLimitExceeded
              | @utf8.Malformed(_) => 4
              _ => 5
            },
          )
          return
        }
      }
    }
  }
}
