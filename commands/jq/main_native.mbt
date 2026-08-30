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
}

///|
priv enum CliParseResult {
  Help
  Error(String)
  Run(CliOptions)
}

///|
fn help_message() -> String {
  "Usage: jq [-clnr] [-f FILTER_FILE] [FILTER] [FILE...]"
}

///|
fn parse_cli(args : ArrayView[String]) -> CliParseResult {
  let parsed = @cli.parse(args, [
    @cli.flag("compact-output", short='c'),
    @cli.flag("logs", short='l'),
    @cli.flag("null-input", short='n'),
    @cli.flag("raw-output", short='r'),
    @cli.option("from-file", short='f'),
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
fn render_result(
  value : Json,
  raw_output : Bool,
  compact_output : Bool,
) -> String {
  if raw_output {
    match value {
      String(text) => text
      _ => value.stringify(indent=if compact_output { 0 } else { 2 })
    }
  } else {
    value.stringify(indent=if compact_output { 0 } else { 2 })
  }
}

///|
async fn write_results(
  results : Iter[Json],
  raw_output : Bool,
  compact_output : Bool,
) -> Unit {
  for value in results {
    @stdio.stdout.write(render_result(value, raw_output, compact_output))
    @stdio.stdout.write("\n")
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
      let query = @moonjq.parse(query_text) catch {
        err => {
          @stdio.stderr.write("moonjq: \{err}\n")
          @sys.exit(3)
          return
        }
      }
      try {
        if options.null_input {
          write_results(
            query.eval(null),
            options.raw_output,
            options.compact_output,
          )
        } else {
          for input_source in options.inputs {
            let input = read_input(input_source)
            write_results(
              run_query(query, input, options.logs),
              options.raw_output,
              options.compact_output,
            )
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
