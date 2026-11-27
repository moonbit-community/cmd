///|
async fn usage_error(
  command : String,
  message : String,
  trailer~ : Bool = true,
) -> Int32 {
  @stdio.stderr.text.write("\{command}: \{message}\n")
  if trailer {
    @stdio.stderr.text.write("Try '\{command} --help' for more information.\n")
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
  let command = fixed.map(a => a.label().to_lower() + "sum").unwrap_or("cksum")
  let specs = checksum_options(modern)
  let parsed = @args.parse(args, specs) catch {
    @args.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("\{command}: \{message}: '\{option}'\n")
      return 1
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.text.write(help_message(command, modern))
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("\{command} \{version}\n")
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
        @stdio.stderr.text.write(
          "cksum: invalid argument '\{name}' for '--algorithm'\n",
        )
        @stdio.stderr.text.write(
          "Valid arguments are:\n  - 'bsd'\n  - 'sysv'\n  - 'crc'\n  - 'crc32b'\n  - 'md5'\n  - 'sha1'\n  - 'sha224'\n  - 'sha256'\n  - 'sha384'\n  - 'sha512'\n  - 'sha2'\n  - 'sha3'\n  - 'blake2b'\n  - 'sm3'\n",
        )
        @stdio.stderr.text.write("Try 'cksum --help' for more information.\n")
        return 1
      }
    }
  }
  let algorithm : Digest = if fixed is Some(fixed) {
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
      @stdio.stderr.text.write(
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
      @stdio.stderr.text.write(
        "\{command}: invalid length: '\{length_text.unwrap_or("")}'\n",
      )
      return usage_error(
        command,
        "maximum digest length for 'BLAKE2b' is 512 bits",
        trailer=false,
      )
    }
    if length % 8L != 0L {
      @stdio.stderr.text.write(
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
  let binary_marker = match binary_choice {
    Some(choice) => choice == "binary"
    None => @platform.is_windows()
  }
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
          @stdio.stderr.text.write(
            "\{command}: \{name}: \{error_message(error)}\n",
          )
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
          @stdio.stderr.text.write(
            "\{command}: \{quote_name(source)}: \{error_message(error)}\n",
          )
          failed = true
          continue
        }
      }
      if raw {
        @stdio.stdout.write(digest)
      } else {
        @stdio.stdout.text.write(
          output_record(
            spec, digest, count, source, implicit, tagged, binary_marker, zero, base64,
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
