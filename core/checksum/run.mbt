///|
fn help_message(command : String, modern : Bool) -> String {
  let extra = if modern {
    "  -a, --algorithm=TYPE  bsd, sysv, crc (default), crc32b, md5, sha1,\n" +
    "                        sha224, sha256, sha384, sha512, sha2, sha3, blake2b, sm3\n" +
    "  -l, --length=BITS     SHA2/SHA3: 224, 256, 384, 512; BLAKE2b: 8..512 by 8\n" +
    "      --untagged        omit algorithm tags (modern digests default to tags)\n" +
    "      --base64          encode modern digests in Base64\n" +
    "      --raw             write digest bytes without names or separators\n"
  } else {
    ""
  }
  "Usage: \{command} [OPTION]... [FILE]...\n" +
  "Print or check checksums. With no FILE, or FILE -, read stdin.\n\n" +
  extra +
  "  -b, --binary          mark untagged output as binary\n" +
  "  -t, --text            mark untagged output as text (default)\n" +
  "      --tag             print BSD tagged records\n" +
  "  -c, --check           read checksum records and verify files\n" +
  "  -z, --zero            end output records with NUL; disable escaping\n" +
  "      --ignore-missing  skip missing files when checking\n" +
  "      --quiet           suppress successful verification output\n" +
  "      --status          suppress verification results and summaries\n" +
  "      --strict          fail if a checksum line is malformed\n" +
  "  -w, --warn            warn for each malformed checksum line\n" +
  "      --help            display this help and exit\n" +
  "      --version         display version and exit\n\n" +
  "Input bytes are unchanged by -b or -t on every supported platform.\n"
}

///|
async fn usage_error(
  command : String,
  message : String,
  trailer~ : Bool = true,
) -> Int32 {
  @stdio.stderr.write("\{command}: \{message}\n")
  if trailer {
    @stdio.stderr.write("Try '\{command} --help' for more information.\n")
  }
  1
}

///|
async fn run_command(
  fixed : Algorithm?,
  args : ArrayView[String],
  version : String,
) -> Int32 {
  let modern = fixed is None
  let command = fixed.map(a => a.command()).unwrap_or("cksum")
  let specs = [
    @cli.flag("check", short='c'),
    @cli.flag("zero", short='z'),
    @cli.flag("binary", short='b'),
    @cli.flag("text", short='t'),
    @cli.flag("tag"),
    @cli.flag("quiet"),
    @cli.flag("status"),
    @cli.flag("strict"),
    @cli.flag("warn", short='w'),
    @cli.flag("ignore-missing"),
    @cli.flag("help"),
    @cli.flag("version"),
  ]
  if modern {
    specs.push(@cli.option("algorithm", short='a'))
    specs.push(@cli.option("length", short='l'))
    specs.push(@cli.flag("untagged"))
    specs.push(@cli.flag("base64"))
    specs.push(@cli.flag("raw"))
  }
  let parsed = @cli.parse(args, specs) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("\{command}: \{message}: '\{option}'\n")
      return 1
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message(command, modern))
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.write("\{command} \{version}\n")
    return 0
  }
  let check = parsed.contains("check")
  let zero = parsed.contains("zero")
  let raw = parsed.contains("raw")
  let base64 = parsed.contains("base64")
  let selection = parsed.last_value("algorithm")
  let mut selected_algorithm : Digest? = None
  for name in parsed.values("algorithm") {
    selected_algorithm = match named_algorithm(name) {
      Some(algorithm) => Some(algorithm)
      None => {
        @stdio.stderr.write(
          "cksum: invalid argument '\{name}' for '--algorithm'\n",
        )
        @stdio.stderr.write(
          "Valid arguments are:\n  - 'bsd'\n  - 'sysv'\n  - 'crc'\n  - 'crc32b'\n  - 'md5'\n  - 'sha1'\n  - 'sha224'\n  - 'sha256'\n  - 'sha384'\n  - 'sha512'\n  - 'sha2'\n  - 'sha3'\n  - 'blake2b'\n  - 'sm3'\n",
        )
        @stdio.stderr.write("Try 'cksum --help' for more information.\n")
        return 1
      }
    }
  }
  let algorithm = if fixed is Some(fixed) {
    Fixed(fixed)
  } else {
    selected_algorithm.unwrap_or(Crc)
  }
  let length_text = parsed.last_value("length")
  let mut length = 0L
  for value in parsed.values("length") {
    let parsed_length = @string.parse_int64(value[:]) catch {
      _ =>
        return usage_error(command, "invalid length: '\{value}'", trailer=false)
    }
    if parsed_length < 0L {
      return usage_error(
        command,
        "invalid length: '\{value}': Value too large to be stored in data type",
        trailer=false,
      )
    }
    length = parsed_length
  }
  if length != 0L && !(algorithm is (Sha2 | Sha3 | Blake2b)) {
    return usage_error(
      command,
      "--length is only supported with --algorithm blake2b, sha2, or sha3",
      trailer=false,
    )
  }
  if algorithm is (Sha2 | Sha3) {
    if length_text is None && !check {
      return usage_error(
        command,
        "--algorithm=\{algorithm.label().to_lower()} requires specifying --length 224, 256, 384, or 512",
        trailer=false,
      )
    }
    if (!check || length_text is Some(_)) &&
      !(length is (224L | 256L | 384L | 512L)) {
      @stdio.stderr.write(
        "\{command}: invalid length: '\{length_text.unwrap_or("")}'\n",
      )
      return usage_error(
        command,
        "digest length for '\{algorithm.label()}' must be 224, 256, 384, or 512",
        trailer=false,
      )
    }
  }
  if algorithm is Blake2b {
    if length > 512L {
      @stdio.stderr.write(
        "\{command}: invalid length: '\{length_text.unwrap_or("")}'\n",
      )
      return usage_error(
        command,
        "maximum digest length for 'BLAKE2b' is 512 bits",
        trailer=false,
      )
    }
    if length % 8L != 0L {
      @stdio.stderr.write(
        "\{command}: invalid length: '\{length_text.unwrap_or("")}'\n",
      )
      return usage_error(
        command,
        "length is not a multiple of 8",
        trailer=false,
      )
    }
  }
  if check && selection is Some(_) && algorithm.legacy() {
    return usage_error(
      command,
      "--check is not supported with --algorithm={bsd,sysv,crc,crc32b}",
      trailer=false,
    )
  }
  if base64 && raw {
    return usage_error(command, "--base64 and --raw are mutually exclusive")
  }
  if check && zero {
    return usage_error(
      command, "the --zero option is not supported when verifying checksums",
    )
  }
  let tag_choice = parsed.last_occurrence(["tag", "untagged"])
  let binary_choice = parsed.last_occurrence(["binary", "text"])
  if check && tag_choice == Some("tag") {
    return usage_error(
      command, "the --tag option is meaningless when verifying checksums",
    )
  }
  if check && binary_choice is Some(_) {
    return usage_error(
      command, "the --binary and --text options are meaningless when verifying checksums",
    )
  }
  let mode = parsed.last_occurrence(["quiet", "status", "warn"])
  let quiet = mode == Some("quiet")
  let status = mode == Some("status")
  let warn = mode == Some("warn")
  let strict = parsed.contains("strict")
  let ignore_missing = parsed.contains("ignore-missing")
  if !check {
    for name in ["ignore-missing", "status", "warn", "quiet", "strict"] {
      let active = match name {
        "status" => status
        "warn" => warn
        "quiet" => quiet
        _ => parsed.contains(name)
      }
      if active {
        return usage_error(
          command,
          "the --\{name} option is meaningful only when verifying checksums",
        )
      }
    }
  }
  let tagged = tag_choice == Some("tag") || (modern && tag_choice is None)
  if tagged && binary_choice == Some("text") {
    return usage_error(
      command,
      if modern {
        "--text mode is only supported with --untagged"
      } else {
        "--tag does not support --text mode"
      },
    )
  }
  if raw && parsed.operands.length() > 1 {
    return usage_error(
      command,
      "the --raw option is not supported with multiple files",
      trailer=false,
    )
  }
  let implicit = parsed.operands.is_empty()
  let sources = if implicit { ["-"] } else { parsed.operands }
  let spec : DigestSpec = {
    algorithm,
    bits: if length == 0L {
      algorithm.default_bits()
    } else {
      length.to_int()
    },
  }
  let mut failed = false
  if check {
    let options : CheckOptions = {
      command,
      selected: if modern && selection is None {
        None
      } else {
        Some(algorithm)
      },
      modern,
      quiet,
      status,
      strict,
      warn,
      ignore_missing,
    }
    let format : ManifestFormat = {
      reversed: -1,
      label: algorithm.label(),
      sha2_tag: None,
    }
    for source in sources {
      let success = check_manifest(source, options, format) catch {
        error => {
          let name = if source == "-" {
            "standard input"
          } else {
            quote_name(source)
          }
          @stdio.stderr.write("\{command}: \{name}: \{error_message(error)}\n")
          false
        }
      }
      if !success {
        failed = true
      }
    }
  } else {
    for source in sources {
      let (digest, count) = digest_source(spec, source) catch {
        error => {
          @stdio.stderr.write(
            "\{command}: \{quote_name(source)}: \{error_message(error)}\n",
          )
          failed = true
          continue
        }
      }
      if raw {
        @stdio.stdout.write(digest)
      } else {
        @stdio.stdout.write(
          output_record(
            spec,
            digest,
            count,
            source,
            implicit,
            tagged,
            binary_choice == Some("binary"),
            zero,
            base64,
          ),
        )
      }
    }
  }
  if failed {
    1
  } else {
    0
  }
}

///|
/// Run a fixed-algorithm checksum command. The executable supplies its version.
pub async fn run(
  algorithm : Algorithm,
  args : ArrayView[String],
  version : String,
) -> Int32 {
  run_command(Some(algorithm), args, version)
}

///|
/// Run cksum with legacy checksums or explicitly selected modern digests.
pub async fn run_cksum(args : ArrayView[String], version : String) -> Int32 {
  run_command(None, args, version)
}
