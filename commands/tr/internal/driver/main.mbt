///|
let command : @argparse.Command = @argparse.Command(
  "tr",
  flags=command_flags(),
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
async fn transform_stream(
  delete : FixedArray[Bool]?,
  translate : FixedArray[Byte]?,
  squeeze : FixedArray[Bool]?,
) -> Unit {
  let mut previous = -1
  while @stream.read_chunk(@stdio.stdin) is Some(chunk) {
    let out : Array[Byte] = []
    for input in chunk {
      let input_code = input.to_int()
      if delete is Some(table) && table[input_code] {
        continue
      }
      let byte = match translate {
        Some(table) => table[input_code]
        None => input
      }
      let code = byte.to_int()
      if squeeze is Some(table) && code == previous && table[code] {
        continue
      }
      out.push(byte)
      previous = code
    }
    if !out.is_empty() {
      @stdio.stdout.write(Bytes::from_array(out))
    }
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("tr \{MODULE_VERSION}\n")
    return
  }
  let args = @env.args()[1:]
  let parsed = command.parse(argv=args, env=Map([])) catch {
    error => {
      let text = error.to_string()
      let line = match text.rev_find("' found") {
        Some(end) => text[:end + 7]
        None => text.split("\n").next().unwrap_or(text[:])
      }
      let (message, option) = match line {
        [.. "error: unexpected argument '--", .. rest] => {
          let spelling = rest.strip_suffix("' found").unwrap_or(rest)
          let name = spelling.split("=").next().unwrap_or(spelling).to_owned()
          let message = if spelling.contains("=") &&
            ["delete", "squeeze-repeats", "complement", "truncate-set1", "help"].contains(
              name,
            ) {
            "flag does not accept a value"
          } else {
            "unknown option"
          }
          (message, name)
        }
        [.. "error: unexpected argument '-", .. rest] =>
          (
            "unknown short option",
            rest.strip_suffix("' found").unwrap_or(rest).to_owned(),
          )
        _ => (text, "")
      }
      @stdio.stderr.write("tr: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(metadata_help())
    return
  }
  let delete = parsed.flags.contains("delete")
  let squeeze_repeats = parsed.flags.contains("squeeze-repeats")
  let complement = parsed.flags.contains("complement") ||
    parsed.flags.contains("complement-short")
  let truncate_set1 = parsed.flags.contains("truncate-set1")
  let sets = operands
  if sets.is_empty() {
    @stdio.stderr.write("tr: missing operand\n")
    @sys.exit(1)
    return
  }
  if sets.length() > 2 {
    @stdio.stderr.write("tr: extra operand '\{sets[2]}'\n")
    @sys.exit(1)
    return
  }
  try {
    let set1_details = @sets.expand_set_details(sets[0], None)
    let set1_bytes = if complement {
      @sets.complement_set(set1_details.bytes)
    } else {
      set1_details.bytes
    }
    let set2_details = if sets.length() > 1 {
      Some(@sets.expand_set_details(sets[1], Some(set1_bytes.length())))
    } else {
      None
    }
    if @env.get_env_var("POSIXLY_CORRECT") is None {
      for warning in set1_details.warnings {
        @stdio.stderr.write(warning)
      }
      for details in set2_details {
        for warning in details.warnings {
          @stdio.stderr.write(warning)
        }
      }
    }
    let set2_bytes = match set2_details {
      Some(details) => details.bytes
      None => []
    }
    if !delete && sets.length() == 1 && !squeeze_repeats {
      raise @sets.CliError("tr: two sets must be given when translating")
    }
    if delete && sets.length() > 1 && !squeeze_repeats {
      raise @sets.CliError(
        "tr: extra operand '\{sets[1]}' (a second set is only used with -s)",
      )
    }
    if delete && squeeze_repeats && sets.length() == 1 {
      raise @sets.CliError(
        "tr: two sets must be given when both deleting and squeezing repeats",
      )
    }
    if !delete && sets.length() > 1 && set2_details is Some(details) {
      @sets.validate_translation_sets(set1_details, details, complement)
    } else if set2_details is Some(details) && details.indefinite_repeats > 0 {
      raise @sets.CliError(
        "tr: [c*] repetition in SET2 is valid only when translating",
      )
    }
    if delete {
      transform_stream(
        Some(@sets.membership(set1_bytes)),
        None,
        if squeeze_repeats && sets.length() > 1 {
          Some(@sets.membership(set2_bytes))
        } else {
          None
        },
      )
    } else if sets.length() > 1 {
      if set2_bytes.is_empty() {
        raise @sets.CliError("tr: SET2 must be non-empty when translating")
      }
      let map = FixedArray::make(256, b'\x00')
      for code in 0..<=255 {
        map[code] = code.to_byte()
      }
      let translate_count = if truncate_set1 &&
        set2_bytes.length() < set1_bytes.length() {
        set2_bytes.length()
      } else {
        set1_bytes.length()
      }
      for index in 0..<translate_count {
        let from = set1_bytes[index]
        let to = if index < set2_bytes.length() {
          set2_bytes[index]
        } else {
          set2_bytes[set2_bytes.length() - 1]
        }
        map[from.to_int()] = to
      }
      transform_stream(
        None,
        Some(map),
        if squeeze_repeats {
          Some(@sets.membership(set2_bytes))
        } else {
          None
        },
      )
    } else {
      // -s with a single set.
      transform_stream(None, None, Some(@sets.membership(set1_bytes)))
    }
  } catch {
    @sets.CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(1)
      return
    }
    err => {
      @stdio.stderr.write("tr: \{err}\n")
      @sys.exit(1)
      return
    }
  }
}
