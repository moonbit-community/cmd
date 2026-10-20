///|
priv struct CheckSummary {
  mut checked : Int32
  mut verified : Int32
  mut mismatched : Int32
  mut unreadable : Int32
  mut malformed : Int32
}

///|
async fn check_manifest(
  algorithm : Algorithm,
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
  let command = algorithm.command()
  for line_index, line in text.split("\n") {
    // A trailing carriage return is a checksum-file line ending, not a
    // filename byte. A filename containing CR must use the escaped form.
    let line = if line.has_suffix("\r") {
      line[:line.length() - 1].to_owned()
    } else {
      line.to_owned()
    }
    if line == "" || line.has_prefix("#") {
      continue
    }
    let (expected, name) = match parse_record(algorithm, line) {
      Some(record) => record
      None => {
        if warn_malformed && !status_only {
          @stdio.stderr.write(
            "\{command}: \{path}: \{line_index + 1}: improperly formatted \{algorithm.label()} checksum line\n",
          )
        }
        summary.malformed += 1
        continue
      }
    }
    summary.checked += 1
    let actual = digest_source(algorithm, name) catch {
      @os_error.OSError(_) as err if ignore_missing &&
        name != "-" &&
        err.is_ENOENT() => continue
      err => {
        if !status_only {
          @stdio.stderr.write("\{command}: '\{name}': \{err}\n")
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
fn help_message(algorithm : Algorithm) -> String {
  let command = algorithm.command()
  let label = algorithm.label()
  "Usage: \{command} [OPTION]... [FILE]...\n" +
  "Print or check \{label} checksums. With no FILE, or FILE -, read stdin.\n\n" +
  "  -b, --binary          mark output as binary\n" +
  "  -t, --text            mark output as text (default)\n" +
  "  -c, --check           read checksums from FILEs and check them\n" +
  "  -z, --zero            end output records with NUL; disable escaping\n" +
  "      --ignore-missing  skip missing files when checking\n" +
  "      --quiet           suppress successful verification output\n" +
  "      --status          suppress verification output\n" +
  "      --strict          fail if a checksum line is malformed\n" +
  "  -w, --warn            warn for each malformed checksum line\n" +
  "      --help            display this help and exit\n" +
  "      --version         display version and exit\n\n" +
  "Checks use standard GNU untagged records. BSD tagged records are not supported.\n" +
  "Input bytes are unchanged by -b or -t on every supported platform.\n"
}

///|
/// Run the shared streaming checksum command and return its exit status.
/// `version` belongs to the executable module, independently of cli/core.
pub async fn run(
  algorithm : Algorithm,
  args : ArrayView[String],
  version : String,
) -> Int32 {
  let command = algorithm.command()
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
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("\{command}: \{message}: '\{option}'\n")
      return 1
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message(algorithm))
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("\{command} \{version}\n")
    return 0
  }
  let check = parsed.contains("check")
  let zero = parsed.contains("zero")
  let quiet = parsed.contains("quiet")
  let status_only = parsed.contains("status")
  let strict = parsed.contains("strict")
  let warn_malformed = parsed.contains("warn")
  let ignore_missing = parsed.contains("ignore-missing")
  let binary_output = parsed.last_occurrence(["binary", "text"]) ==
    Some("binary")
  let sources = if parsed.operands.is_empty() { ["-"] } else { parsed.operands }
  let mut failed = false
  if !check &&
    (quiet || status_only || strict || warn_malformed || ignore_missing) {
    @stdio.stderr.write("\{command}: verification options require --check\n")
    return 1
  }
  if check && zero {
    @stdio.stderr.write(
      "\{command}: the --zero option is not supported when verifying checksums\n",
    )
    return 1
  }
  if check {
    for manifest in sources {
      let summary = check_manifest(
        algorithm, manifest, quiet, status_only, ignore_missing, warn_malformed,
      ) catch {
        err => {
          if !status_only {
            @stdio.stderr.write("\{command}: '\{manifest}': \{err}\n")
          }
          failed = true
          continue
        }
      }
      if !status_only && summary.checked == 0 {
        @stdio.stderr.write(
          "\{command}: \{manifest}: no properly formatted checksum lines found\n",
        )
      } else if !status_only {
        if summary.malformed > 0 {
          let noun = if summary.malformed == 1 {
            "line is"
          } else {
            "lines are"
          }
          @stdio.stderr.write(
            "\{command}: WARNING: \{summary.malformed} \{noun} improperly formatted\n",
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
      }
      if ignore_missing &&
        summary.verified == 0 &&
        summary.checked > 0 &&
        !status_only {
        @stdio.stderr.write("\{command}: \{manifest}: no file was verified\n")
      }
      if summary.checked == 0 ||
        summary.mismatched > 0 ||
        summary.unreadable > 0 ||
        (ignore_missing && summary.verified == 0) ||
        (strict && summary.malformed > 0) {
        failed = true
      }
    }
  } else {
    for source in sources {
      let digest = digest_source(algorithm, source) catch {
        err => {
          @stdio.stderr.write("\{command}: '\{source}': \{err}\n")
          failed = true
          continue
        }
      }
      @stdio.stdout.write(format_record(digest, source, binary_output, zero))
    }
  }
  if failed {
    1
  } else {
    0
  }
}
