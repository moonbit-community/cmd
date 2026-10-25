///|
priv struct CheckOptions {
  command : String
  selected : Digest?
  modern : Bool
  quiet : Bool
  status : Bool
  strict : Bool
  warn : Bool
  ignore_missing : Bool
}

///|
priv struct CheckSummary {
  mut checked : Int32
  mut matched : Int32
  mut mismatched : Int32
  mut unreadable : Int32
  mut malformed : Int32
}

///|
async fn check_reader(
  reader : &@io.Reader,
  path : String,
  options : CheckOptions,
  format : ManifestFormat,
) -> Bool {
  let scanner = @stream.LineScanner::new(reader)
  let summary : CheckSummary = {
    checked: 0,
    matched: 0,
    mismatched: 0,
    unreadable: 0,
    malformed: 0,
  }
  let command = options.command
  let manifest = if path == "-" { "standard input" } else { quote_name(path) }
  let mut line_number = 0
  while scanner.next() is Some(raw) {
    line_number += 1
    let text = @utf8.decode_lossy(raw.data[:], ignore_bom=false)
    let line = if text.has_suffix("\r") {
      text[:text.length() - 1].to_owned()
    } else {
      text
    }
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    let record = match
      manifest_record(line, options.selected, options.modern, format) {
      Some(record) if !(path == "-" && record.name == "-") => record
      _ => {
        summary.malformed += 1
        if options.warn {
          let label = format.label
          @stdio.stderr.write(
            "\{command}: \{manifest}: \{line_number}: improperly formatted \{label} checksum line\n",
          )
        }
        continue
      }
    }
    summary.checked += 1
    let (actual, _) = digest_source(record.spec, record.name) catch {
      @os_error.OSError(_) as error if options.ignore_missing &&
        record.name != "-" &&
        error.is_ENOENT() => continue
      error => {
        @stdio.stderr.write(
          "\{command}: \{quote_name(record.name)}: \{error_message(error)}\n",
        )
        if !options.status {
          @stdio.stdout.write(
            "\{quote_name(record.name)}: FAILED open or read\n",
          )
        }
        summary.unreadable += 1
        continue
      }
    }
    if actual == record.expected {
      summary.matched += 1
      if !options.status && !options.quiet {
        @stdio.stdout.write("\{quote_name(record.name)}: OK\n")
      }
    } else {
      summary.mismatched += 1
      if !options.status {
        @stdio.stdout.write("\{quote_name(record.name)}: FAILED\n")
      }
    }
  }
  if summary.checked == 0 {
    @stdio.stderr.write(
      "\{command}: \{manifest}: no properly formatted checksum lines found\n",
    )
  } else if !options.status {
    if summary.malformed > 0 {
      let noun = if summary.malformed == 1 { "line is" } else { "lines are" }
      @stdio.stderr.write(
        "\{command}: WARNING: \{summary.malformed} \{noun} improperly formatted\n",
      )
    }
    if summary.unreadable > 0 {
      let noun = if summary.unreadable == 1 {
        "file could"
      } else {
        "files could"
      }
      @stdio.stderr.write(
        "\{command}: WARNING: \{summary.unreadable} listed \{noun} not be read\n",
      )
    }
    if summary.mismatched > 0 {
      let noun = if summary.mismatched == 1 {
        "checksum did"
      } else {
        "checksums did"
      }
      @stdio.stderr.write(
        "\{command}: WARNING: \{summary.mismatched} computed \{noun} NOT match\n",
      )
    }
    if options.ignore_missing && summary.matched == 0 {
      @stdio.stderr.write("\{command}: \{manifest}: no file was verified\n")
    }
  }
  summary.checked > 0 &&
  summary.matched > 0 &&
  summary.mismatched == 0 &&
  summary.unreadable == 0 &&
  (!options.strict || summary.malformed == 0)
}

///|
async fn check_manifest(
  path : String,
  options : CheckOptions,
  format : ManifestFormat,
) -> Bool {
  if path == "-" {
    return check_reader(@stdio.stdin, path, options, format)
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  if file.kind() is Directory {
    raise DigestError("read error")
  }
  check_reader(file, path, options, format)
}
