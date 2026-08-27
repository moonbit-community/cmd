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
    if line.length() < 67 ||
      line[64] != ' ' ||
      (line[65] != ' ' && line[65] != '*') {
      @stdio.stderr.write("sha256sum: improperly formatted checksum line\n")
      failed += 1
      continue
    }
    let expected = line[0:64].to_owned().to_lower()
    let name = line[66:].to_owned()
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
      @stdio.stdout.write("\{actual}  \{source}\{separator}")
    }
  }
  if failed {
    @sys.exit(1)
  }
}
