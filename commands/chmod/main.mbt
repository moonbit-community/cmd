///|
fn parse_mode(text : String) -> Int raise {
  let digits = if text.has_prefix("0o") || text.has_prefix("0O") {
    text[2:].to_owned()
  } else {
    text
  }
  if digits == "" {
    fail("empty mode")
  }
  let mut value = 0
  for digit in digits {
    if !(digit is ('0'..='7')) {
      fail("invalid mode")
    }
    value = value * 8 + digit.to_int() - '0'.to_int()
    if value > 0o7777 {
      fail("mode out of range")
    }
  }
  value
}

///|
fn mode_text(mode : Int) -> String {
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
fn parse_symbolic_mode(text : String) -> Int raise ChmodError {
  if text == "" {
    raise ChmodError("empty symbolic mode")
  }
  let mut mode = 0
  let mut user = false
  let mut group = false
  let mut other = false
  for clause_view in text.split(",") {
    let clause = clause_view.to_owned()
    guard clause.find("=") is Some(equal) else {
      raise ChmodError("symbolic mode must use '='")
    }
    if clause[equal + 1:].contains("=") || equal == 0 {
      raise ChmodError("invalid symbolic assignment: '\{clause}'")
    }
    let mut clause_user = false
    let mut clause_group = false
    let mut clause_other = false
    for who in clause[:equal] {
      match who {
        'u' => clause_user = true
        'g' => clause_group = true
        'o' => clause_other = true
        'a' => {
          clause_user = true
          clause_group = true
          clause_other = true
        }
        _ => raise ChmodError("invalid symbolic class: '\{who}'")
      }
    }
    let mut permissions = 0
    for permission in clause[equal + 1:] {
      match permission {
        'r' => permissions = permissions | 4
        'w' => permissions = permissions | 2
        'x' => permissions = permissions | 1
        _ =>
          raise ChmodError("unsupported symbolic permission: '\{permission}'")
      }
    }
    if clause_user {
      user = true
      mode = (mode & (0o700).lnot()) | (permissions << 6)
    }
    if clause_group {
      group = true
      mode = (mode & (0o070).lnot()) | (permissions << 3)
    }
    if clause_other {
      other = true
      mode = (mode & (0o007).lnot()) | permissions
    }
  }
  if !user || !group || !other {
    raise ChmodError("symbolic mode must explicitly assign u, g, and o")
  }
  mode
}

///|
async fn chmod_numeric_path(
  path : String,
  mode : Int,
  recursive : Bool,
  verbose : Bool,
) -> Unit {
  match @fs.kind(path, follow_symlink=false) {
    SymLink => raise ChmodError("refusing to chmod symbolic link: \{path}")
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
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("recursive", short='R'),
    @cli.flag("verbose", short='v'),
    @cli.option("reference"),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("chmod: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: chmod [-R] [-v] MODE FILE...\n       chmod [-R] [-v] --reference=RFILE FILE...\nMODE may be numeric or a complete symbolic '=' assignment such as a=rwx or u=rw,g=r,o=.\n",
    )
    return
  }
  if parsed.contains("reference") {
    if parsed.operands.is_empty() {
      @stdio.stderr.write("chmod: missing operand\n")
      @sys.exit(1)
      return
    }
    @stdio.stderr.write(
      "chmod: --reference is unavailable: the portable filesystem API cannot read permission bits\n",
    )
    @sys.exit(1)
    return
  }
  let (selected_mode, symbolic_mode) = match parsed.operands.get(0) {
    Some(value) => {
      let numeric = try parse_mode(value) catch {
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
                @sys.exit(2)
                return
              }
            },
            true,
          )
      }
    }
    None => {
      @stdio.stderr.write("chmod: missing mode\n")
      @sys.exit(2)
      return
    }
  }
  let operands = parsed.operands[1:]
  if operands.is_empty() {
    @stdio.stderr.write("chmod: missing operand\n")
    @sys.exit(2)
    return
  }
  if !@platform.permission_mutation_supported() {
    @stdio.stderr.write("chmod: unsupported capability: permission mutation\n")
    @sys.exit(1)
    return
  }
  let verbose = parsed.contains("verbose")
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
      @sys.exit(1)
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
        parsed.contains("recursive"),
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
    @sys.exit(1)
  }
}
