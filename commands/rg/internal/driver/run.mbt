///|
/// The result of parsing CLI arguments.
pub(all) enum ParseResult[T] {
  Special(SpecialMode)
  ParseOk(T)
  ParseErr(String)
}

///|
fn set_log_levels(low : LowArgs) -> Unit {
  set_messages(!low.no_messages)
  set_ignore_messages(!low.no_ignore_messages)
  log_level.val = match low.logging {
    Some(Trace) => 2
    Some(Debug) => 1
    None => 0
  }
}

///|
/// Parses the CLI arguments (excluding the program name), including any
/// arguments from a config file.
pub async fn parse_low(cli_args : Array[String]) -> ParseResult[LowArgs] {
  let low = LowArgs::default()
  parse_into(cli_args, low) catch {
    e => return ParseErr(e.message())
  }
  set_log_levels(low)
  if low.special is Some(special) {
    return Special(special)
  }
  if low.no_config {
    log_debug(
      "rg::flags::parse", "not reading config files because --no-config is present",
    )
    return ParseOk(low)
  }
  let config = config_args()
  if config.is_empty() {
    log_debug(
      "rg::flags::parse", "no extra arguments found from configuration file",
    )
    return ParseOk(low)
  }
  let final_args = config.copy()
  final_args.append(cli_args)
  let low = LowArgs::default()
  parse_into(final_args, low) catch {
    e => return ParseErr(e.message())
  }
  set_log_levels(low)
  ParseOk(low)
}

///|
/// Writes the string to stdout. Returns false on a broken pipe.
async fn write_stdout_str(s : String) -> Unit {
  let bytes = @utf8.encode(s).to_fixedarray()
  @sys.write_fd(1, bytes, 0, bytes.length())
}

///|
async fn special(mode : SpecialMode) -> Int32 {
  let mut exit = 0
  let output = match mode {
    HelpShort => generate_help_short()
    HelpLong => generate_help_long()
    VersionShort => generate_version_short()
    VersionLong => generate_version_long()
    VersionPCRE2 => {
      let (output, available) = generate_version_pcre2()
      if !available {
        exit = 1
      }
      output
    }
  }
  write_stdout_str(output.trim_end().to_owned() + "\n")
  exit
}

///|
async fn generate(mode : GenerateMode) -> Int32 {
  let output = match mode {
    Man => generate_man_page()
    CompleteBash => generate_complete_bash()
    CompleteZsh => generate_complete_zsh()
    CompleteFish => generate_complete_fish()
    CompletePowerShell => generate_complete_powershell()
  }
  write_stdout_str(output.trim_end().to_owned() + "\n")
  0
}

///|
/// Runs ripgrep with the given arguments (excluding the program name) and
/// returns the exit code.
pub async fn run_main(cli_args : Array[String]) -> Int32 {
  if cli_args == ["--version"] {
    write_stdout_str(generate_version_short() + "\n")
    return 0
  }
  if cli_args == ["--help"] {
    write_stdout_str(generate_help_long().trim_end().to_owned() + "\n")
    return 0
  }
  let result = try run(cli_args) catch {
    RgError(msg) => Err(msg)
    @sys.IOError(kind~, ..) as e =>
      if kind is BrokenPipe {
        Ok(0)
      } else {
        Err(e.to_string())
      }
    e => Err("\{e}")
  } noraise {
    code => Ok(code)
  }
  match result {
    Ok(code) => code
    Err(msg) => {
      eprintln_locked(msg)
      2
    }
  }
}

///|
async fn run(cli_args : Array[String]) -> Int32 {
  let low = match parse_low(cli_args) {
    ParseErr(msg) => raise RgError(msg)
    Special(mode) => return special(mode)
    ParseOk(low) => low
  }
  let args = HiArgs::from_low_args(low)
  let matched = match args.mode() {
    Search(_) if !args.matches_possible() => false
    Search(mode) => run_search(args, mode)
    Index(_) => raise RgError(INDEXING_NOT_SUPPORTED)
    Files => run_files(args)
    Types => return run_types(args)
    Generate(mode) => return generate(mode)
  }
  if matched && (args.quiet() || !errored()) {
    0
  } else if errored() {
    2
  } else {
    1
  }
}
