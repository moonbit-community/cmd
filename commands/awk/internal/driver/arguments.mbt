///|
priv struct Invocation {
  csv : Bool
  program : String
  assignments : Array[(String, String)]
  operands : Array[String]
}

///|
fn assignment(text : String) -> (String, String)? {
  guard text.split_once("=") is Some((key, value)) else { return None }
  guard !key.is_empty() else { return None }
  for i, ch in key {
    guard (ch >= 'A' && ch <= 'Z') ||
      (ch >= 'a' && ch <= 'z') ||
      ch == '_' ||
      (i > 0 && ch >= '0' && ch <= '9') else {
      return None
    }
  }
  Some((key.to_owned(), value.to_owned()))
}

///|
async fn invocation(args : ArrayView[String]) -> Invocation {
  let mut i = 0
  while i < args.length() {
    let option = args[i]
    if option == "--" {
      i += 1
      break
    }
    if option == "-" || !option.has_prefix("-") {
      break
    }
    i += 1
    if [
        "-f", "--file", "-F", "--field-separator", "-v", "--assign", "-e", "--source",
      ].contains(option) &&
      i < args.length() {
      i += 1
    }
  }
  let parsed = @cli.parse(args[:i], option_specs()) catch {
    @cli.CliError(message~, ..) => raise Failure(message)
  }
  let assignments = []
  let sources = []
  let counts : Map[String, Int32] = Map([])
  for name in parsed.order {
    let offset = counts.get(name).unwrap_or(0)
    counts[name] = offset + 1
    let value = parsed.occurrences[name][offset].unwrap_or("")
    match name {
      "field-separator" => assignments.push(("FS", value))
      "assign" => {
        guard assignment(value) is Some(pair) else {
          raise Failure("expected NAME=VALUE: " + value)
        }
        assignments.push(pair)
      }
      "csv" => ()
      "source" => sources.push(value)
      "file" => {
        let bytes = if value == "-" {
          @stdio.stdin.read_all()
        } else {
          @fs.read_binary(value)
        }
        sources.push(
          @utf8.decode(bytes, ignore_bom=false) catch {
            _ => raise Failure("invalid UTF-8 program: " + value)
          },
        )
      }
      _ => raise Failure("--" + name + " must be used alone")
    }
  }
  if sources.is_empty() {
    guard i < args.length() else { raise Failure("missing program") }
    sources.push(args[i])
    i += 1
  }
  {
    csv: parsed.contains("csv"),
    program: sources.join("\n"),
    assignments,
    operands: args[i:].to_owned(),
  }
}
