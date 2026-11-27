///|
let command : @argparse.Command = @argparse.Command(
  "chmod",
  flags=command_flags(),
  options=command_options(),
  positionals=[
    @argparse.PositionArg("operands", num_args=@argparse.ValueRange()),
  ],
  disable_help_flag=true,
  disable_version_flag=true,
  disable_help_subcommand=true,
)

///|
fn mode_text(mode : Int32) -> String {
  let digits = "01234567"
  let out = StringBuilder()
  out.write_char('0')
  let first_shift = if mode > 0o777 { 0 } else { 1 }
  for shift in first_shift..<=3 {
    let value = (mode >> ((3 - shift) * 3)) & 0x7
    out.write_char(digits.get_char(value).unwrap())
  }
  out.to_string()
}

///|
priv suberror ChmodError {
  ChmodError(String)
}

///|
async fn chmod_numeric_path(
  path : String,
  mode : Int32,
  recursive : Bool,
  verbose : Bool,
  command_line~ : Bool = true,
) -> Unit {
  match @fs.kind(path, follow_symlink=false) {
    SymLink =>
      if command_line {
        @fs.chmod(path, mode)
        if verbose {
          @stdio.stdout.write(
            "mode of '\{path}' changed to \{mode_text(mode)}\n",
          )
        }
      }
    Directory => {
      @fs.chmod(path, mode)
      if verbose {
        @stdio.stdout.write("mode of '\{path}' changed to \{mode_text(mode)}\n")
      }
      if recursive {
        let entries = @fs.readdir(
          path,
          include_hidden=true,
          include_special=false,
          sort=true,
        )
        for entry in entries {
          chmod_numeric_path(
            @path.Path(path).join(Path(entry)).to_string(),
            mode,
            true,
            verbose,
            command_line=false,
          )
        }
      }
    }
    _ => {
      @fs.chmod(path, mode)
      if verbose {
        @stdio.stdout.write("mode of '\{path}' changed to \{mode_text(mode)}\n")
      }
    }
  }
}

///|
pub async fn run_main() -> Unit {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("chmod \{MODULE_VERSION}\n")
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
            ["recursive", "verbose", "help"].contains(name) {
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
        [.. "error: a value is required for '", .. rest] => {
          let spelling = rest
            .strip_suffix("' but none was supplied")
            .unwrap_or(rest)
          let name = spelling.strip_prefix("--").unwrap_or(spelling).to_owned()
          ("option requires a value", name)
        }
        _ => (text, "")
      }
      @stdio.stderr.write("chmod: \{message}: '\{option}'\n")
      @env.exit(1)
      return
    }
  }
  let operands = parsed.values.get("operands").unwrap_or([])
  if parsed.flags.contains("help") {
    @stdio.stdout.write(metadata_help())
    return
  }
  if parsed.values.contains("reference") {
    if operands.is_empty() {
      @stdio.stderr.write("chmod: missing operand\n")
      @env.exit(1)
      return
    }
    @stdio.stderr.write(
      "chmod: --reference is unavailable: the portable filesystem API cannot read permission bits\n",
    )
    @env.exit(1)
    return
  }
  let (selected_mode, symbolic_mode) = match operands.get(0) {
    Some(value) => {
      let numeric = try parse_octal_mode(value) catch {
        _ => None
      } noraise {
        mode => Some(mode)
      }
      match numeric {
        Some(mode) => (mode, false)
        None =>
          (
            parse_symbolic_mode(value) catch {
              ChmodError(message) => {
                @stdio.stderr.write(
                  "chmod: invalid mode '\{value}': \{message}\n",
                )
                @env.exit(1)
                return
              }
            },
            true,
          )
      }
    }
    None => {
      @stdio.stderr.write("chmod: missing mode\n")
      @env.exit(1)
      return
    }
  }
  let operands = operands[1:]
  if operands.is_empty() {
    @stdio.stderr.write("chmod: missing operand\n")
    @env.exit(1)
    return
  }
  if !@platform.permission_mutation_supported() {
    @stdio.stderr.write("chmod: unsupported capability: permission mutation\n")
    @env.exit(1)
    return
  }
  let verbose = parsed.flags.contains("verbose")
  let mut failed = false
  if symbolic_mode {
    for path in operands {
      let kind = @fs.kind(path, follow_symlink=false) catch {
        err => {
          @stdio.stderr.write("chmod: cannot inspect '\{path}': \{err}\n")
          failed = true
          continue
        }
      }
      if kind != Regular {
        @stdio.stderr.write(
          "chmod: symbolic assignments are limited to regular files: '\{path}'\n",
        )
        failed = true
      }
    }
    if failed {
      @env.exit(1)
      return
    }
    for path in operands {
      @fs.chmod(path, selected_mode) catch {
        err => {
          @stdio.stderr.write("chmod: cannot change mode: \{err}\n")
          failed = true
        }
      }
      if !failed && verbose {
        @stdio.stdout.write(
          "mode of '\{path}' changed to \{mode_text(selected_mode)}\n",
        )
      }
    }
  } else {
    for path in operands {
      chmod_numeric_path(
        path,
        selected_mode,
        parsed.flags.contains("recursive"),
        verbose,
      ) catch {
        err => {
          @stdio.stderr.write("chmod: cannot change mode: \{err}\n")
          failed = true
        }
      }
    }
  }
  if failed {
    @env.exit(1)
  }
}
