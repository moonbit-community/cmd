///|
async fn digest_reader(reader : &@io.Reader) -> String {
  let hasher = @crypto.SHA256::new()
  while reader.read_some(max_len=65536) is Some(chunk) {
    hasher.update(chunk)
  }
  @crypto.bytes_to_hex_string(hasher.finalize())
}

///|
async fn digest_source(path : String) -> String {
  if path == "-" {
    digest_reader(@stdio.stdin)
  } else {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    digest_reader(file)
  }
}

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = text.split("\n").map(v => v.to_owned()).collect()
  if text.has_suffix("\n") {
    ignore(lines.pop())
  }
  lines
}

///|
fn is_hex_digest(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for char in value {
    if !(char is ('0'..='9' | 'a'..='f' | 'A'..='F')) {
      return false
    }
  }
  true
}

///|
fn encode_filename(name : String) -> (String, Bool) {
  let output = StringBuilder()
  let mut escaped = false
  for char in name {
    match char {
      '\\' => {
        output.write_string("\\\\")
        escaped = true
      }
      '\n' => {
        output.write_string("\\n")
        escaped = true
      }
      _ => output.write_char(char)
    }
  }
  (output.to_string(), escaped)
}

///|
fn decode_filename(value : String) -> String? {
  let chars : Array[Char] = value.iter().collect()
  let output = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    if chars[index] != '\\' {
      output.write_char(chars[index])
      index += 1
    } else if index + 1 >= chars.length() {
      return None
    } else {
      match chars[index + 1] {
        '\\' => output.write_char('\\')
        'n' => output.write_char('\n')
        _ => return None
      }
      index += 2
    }
  }
  Some(output.to_string())
}

///|
priv struct CheckSummary {
  mut checked : Int
  mut verified : Int
  mut mismatched : Int
  mut unreadable : Int
  mut malformed : Int
}

///|
async fn check_manifest(
  path : String,
  quiet : Bool,
  status_only : Bool,
  ignore_missing : Bool,
  warn_malformed : Bool,
) -> CheckSummary {
  let text = if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
  let summary : CheckSummary = {
    checked: 0,
    verified: 0,
    mismatched: 0,
    unreadable: 0,
    malformed: 0,
  }
  for line_index, line in split_lines(text) {
    if line == "" {
      continue
    }
    let escaped = line.has_prefix("\\")
    let record = if escaped { line[1:].to_owned() } else { line }
    if record.length() < 67 ||
      record[64] != ' ' ||
      (record[65] != ' ' && record[65] != '*') ||
      !is_hex_digest(record[0:64].to_owned()) {
      if warn_malformed && !status_only {
        @stdio.stderr.write(
          "sha256sum: \{path}: \{line_index + 1}: improperly formatted SHA256 checksum line\n",
        )
      }
      summary.malformed += 1
      continue
    }
    let expected = record[0:64].to_owned().to_lower()
    let encoded_name = record[66:].to_owned()
    let name = if escaped {
      match decode_filename(encoded_name) {
        Some(value) => value
        None => {
          if warn_malformed && !status_only {
            @stdio.stderr.write(
              "sha256sum: \{path}: \{line_index + 1}: improperly formatted SHA256 checksum line\n",
            )
          }
          summary.malformed += 1
          continue
        }
      }
    } else {
      encoded_name
    }
    summary.checked += 1
    if ignore_missing && name != "-" && !@fs.exists(name) {
      continue
    }
    let actual = digest_source(name) catch {
      err => {
        @stdio.stderr.write("sha256sum: '\{name}': \{err}\n")
        if !status_only {
          @stdio.stdout.write("\{name}: FAILED open or read\n")
        }
        summary.unreadable += 1
        continue
      }
    }
    summary.verified += 1
    if actual == expected {
      if !status_only && !quiet {
        @stdio.stdout.write("\{name}: OK\n")
      }
    } else {
      if !status_only {
        @stdio.stdout.write("\{name}: FAILED\n")
      }
      summary.mismatched += 1
    }
  }
  summary
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("check", short='c'),
    @cli.flag("zero", short='z'),
    @cli.flag("binary", short='b'),
    @cli.flag("text", short='t'),
    @cli.flag("quiet"),
    @cli.flag("status"),
    @cli.flag("strict"),
    @cli.flag("warn", short='w'),
    @cli.flag("ignore-missing"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("sha256sum: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: sha256sum [-c] [-z] [--quiet] [--status] [--strict] [--warn] [--ignore-missing] [FILE...]\n",
    )
    return
  }
  let files = parsed.operands
  let check = parsed.contains("check")
  let zero = parsed.contains("zero")
  let quiet = parsed.contains("quiet")
  let status_only = parsed.contains("status")
  let strict = parsed.contains("strict")
  let warn_malformed = parsed.contains("warn")
  let ignore_missing = parsed.contains("ignore-missing")
  let binary_output = parsed.last_occurrence(["binary", "text"]) ==
    Some("binary")
  let sources = if files.is_empty() { ["-"] } else { files }
  let mut failed = false
  if !check &&
    (quiet || status_only || strict || warn_malformed || ignore_missing) {
    @stdio.stderr.write("sha256sum: verification options require --check\n")
    @sys.exit(2)
    return
  }
  if check {
    if zero {
      @stdio.stderr.write("sha256sum: -z is not supported with -c\n")
      @sys.exit(2)
      return
    }
    for manifest in sources {
      let summary = check_manifest(
        manifest, quiet, status_only, ignore_missing, warn_malformed,
      ) catch {
        err => {
          @stdio.stderr.write("sha256sum: '\{manifest}': \{err}\n")
          failed = true
          continue
        }
      }
      if !status_only && summary.malformed > 0 {
        let noun = if summary.malformed == 1 { "line is" } else { "lines are" }
        @stdio.stderr.write(
          "sha256sum: WARNING: \{summary.malformed} \{noun} improperly formatted\n",
        )
      }
      if !status_only && summary.mismatched > 0 {
        let noun = if summary.mismatched == 1 {
          "checksum did"
        } else {
          "checksums did"
        }
        @stdio.stderr.write(
          "sha256sum: WARNING: \{summary.mismatched} computed \{noun} NOT match\n",
        )
      }
      if !status_only && summary.unreadable > 0 {
        let noun = if summary.unreadable == 1 {
          "file could"
        } else {
          "files could"
        }
        @stdio.stderr.write(
          "sha256sum: WARNING: \{summary.unreadable} listed \{noun} not be read\n",
        )
      }
      if summary.checked == 0 {
        if !status_only {
          @stdio.stderr.write(
            "sha256sum: \{manifest}: no properly formatted checksum lines found\n",
          )
        }
        failed = true
      }
      if ignore_missing && summary.verified == 0 {
        if !status_only {
          @stdio.stderr.write("sha256sum: \{manifest}: no file was verified\n")
        }
        failed = true
      }
      if summary.mismatched > 0 ||
        summary.unreadable > 0 ||
        (strict && summary.malformed > 0) {
        failed = true
      }
    }
  } else {
    let separator = if zero { "\u0000" } else { "\n" }
    for source in sources {
      let actual = digest_source(source) catch {
        err => {
          @stdio.stderr.write("sha256sum: '\{source}': \{err}\n")
          failed = true
          continue
        }
      }
      if zero {
        let marker = if binary_output { "*" } else { " " }
        @stdio.stdout.write("\{actual} \{marker}\{source}\{separator}")
      } else {
        let (name, escaped) = encode_filename(source)
        let prefix = if escaped { "\\" } else { "" }
        let marker = if binary_output { "*" } else { " " }
        @stdio.stdout.write("\{prefix}\{actual} \{marker}\{name}\{separator}")
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
