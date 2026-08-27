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
async fn check_manifest(path : String) -> (Int, Int) {
  let text = if path == "-" {
    @stdio.stdin.read_all().text()
  } else {
    @fs.read_file(path).text()
  }
  let mut checked = 0
  let mut failed = 0
  for line in split_lines(text) {
    if line == "" {
      continue
    }
    let escaped = line.has_prefix("\\")
    let record = if escaped { line[1:].to_owned() } else { line }
    if record.length() < 67 ||
      record[64] != ' ' ||
      (record[65] != ' ' && record[65] != '*') ||
      !is_hex_digest(record[0:64].to_owned()) {
      @stdio.stderr.write("sha256sum: improperly formatted checksum line\n")
      failed += 1
      continue
    }
    let expected = record[0:64].to_owned().to_lower()
    let encoded_name = record[66:].to_owned()
    let name = if escaped {
      match decode_filename(encoded_name) {
        Some(value) => value
        None => {
          @stdio.stderr.write("sha256sum: improperly escaped file name\n")
          failed += 1
          continue
        }
      }
    } else {
      encoded_name
    }
    let actual = digest_source(name) catch {
      err => {
        @stdio.stderr.write("sha256sum: '\{name}': \{err}\n")
        @stdio.stdout.write("\{name}: FAILED open or read\n")
        checked += 1
        failed += 1
        continue
      }
    }
    checked += 1
    if actual == expected {
      @stdio.stdout.write("\{name}: OK\n")
    } else {
      @stdio.stdout.write("\{name}: FAILED\n")
      failed += 1
    }
  }
  (checked, failed)
}

///|
async fn main {
  let args = @env.args()[1:]
  let files : Array[String] = []
  let mut check = false
  let mut zero = false
  let mut options = true
  for arg in args {
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-c" || arg == "--check") {
      check = true
    } else if options && (arg == "-z" || arg == "--zero") {
      zero = true
    } else if options &&
      (arg == "-b" || arg == "--binary" || arg == "-t" || arg == "--text") {
      ()
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: sha256sum [-c] [-z] [FILE...]\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("sha256sum: invalid option: '\{arg}'\n")
      @sys.exit(2)
      return
    } else {
      files.push(arg)
    }
  }
  let sources = if files.is_empty() { ["-"] } else { files }
  let mut failed = false
  if check {
    if zero {
      @stdio.stderr.write("sha256sum: -z is not supported with -c\n")
      @sys.exit(2)
      return
    }
    for manifest in sources {
      let (checked, errors) = check_manifest(manifest) catch {
        err => {
          @stdio.stderr.write("sha256sum: '\{manifest}': \{err}\n")
          failed = true
          continue
        }
      }
      if checked == 0 || errors > 0 {
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
        @stdio.stdout.write("\{actual}  \{source}\{separator}")
      } else {
        let (name, escaped) = encode_filename(source)
        let prefix = if escaped { "\\" } else { "" }
        @stdio.stdout.write("\{prefix}\{actual}  \{name}\{separator}")
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
