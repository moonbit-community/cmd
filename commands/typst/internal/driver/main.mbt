// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The command line interface of typst.mbt (upstream
// `typst-cli/src/main.rs`).

///|
/// The CLI's exit code.
let exit_code : Ref[Int32] = { val: 0, }

///|
/// Ensure a failure exit code.
fn set_failed() -> Unit {
  exit_code.val = 1
}

///|
pub async fn run_main(argv : Array[String]) -> Int32 {
  exit_code.val = 0
  color_choice.val = Auto
  run(argv) catch {
    error => {
      @platform.print_stderr("typst: \{error}\n") catch {
        _ => ()
      }
      1
    }
  }
}

///|
async fn run(argv : Array[String]) -> Int32 {
  if argv == ["--version"] {
    @platform.print_stdout("typst 0.1.0\n")
    return 0
  }
  if argv == ["--help"] {
    @platform.print_stdout(command_help + "\n")
    return 0
  }
  let args = parse_args(argv) catch {
    Display(text) => {
      print_out_lossy(text)
      return 0
    }
    Usage(message, usage) => {
      print_clap_error(message, Some(usage))
      return 2
    }
    Invalid(message) => {
      print_clap_error(message, None)
      return 2
    }
    MissingSubcommand => {
      if greet() {
        return 0
      }
      @platform.print_stderr(main_spec().help())
      return 2
    }
  }
  color_choice.val = args.color
  dispatch(args) catch {
    HintedFailure(msg) => {
      set_failed()
      print_error(msg.message)
      for hint in msg.hints {
        print_hint(hint)
      }
    }
    error => raise error
  }
  exit_code.val
}

///|
/// Prints a command line parsing error like clap (exit code 2).
async fn print_clap_error(message : String, usage : String?) -> Unit {
  let out = @kit.ColorWriter::new(
    match color_choice.val {
      Always => true
      Never => false
      Auto => @platform.stderr_is_terminal() && @kit.env_allows_color()
    },
  )
  out.set_color(@kit.ColorSpec::new().with_bold().with_fg(Red))
  out.write("error:")
  out.reset()
  out.writeln(" \{message}")
  out.write("\n")
  if usage is Some(usage) {
    out.writeln("Usage: \{usage}")
    // clap's `help` subcommand has no `--help` flag to point to.
    if usage.has_prefix("typst help ") {
      flush_terminal(out)
      return
    }
    out.write("\n")
  }
  out.writeln("For more information, try '--help'.")
  flush_terminal(out)
}

///|
/// Execute the requested command.
async fn dispatch(args : CliArguments) -> Unit {
  match args.command {
    Compile(command) => compile(command)
    Watch(command) => watch(command)
    Init(command) => init_project(command)
    Query(command) => query(command)
    Eval(command) => eval(command)
    Fonts(command) => fonts(command)
    Update =>
      raise bail(
        "self-updating is not enabled for this executable, please update with the package manager or mechanism used for initial installation",
      )
    Completions(_) =>
      raise bail("generating shell completions is not supported by this build")
    Info(command) => info(command)
  }
}
