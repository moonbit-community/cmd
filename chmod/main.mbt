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
async fn chmod_path(
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
          chmod_path(
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
  let operands : Array[String] = []
  let mut recursive = false
  let mut verbose = false
  let mut options = true
  let mut mode : Int? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-R" || arg == "--recursive") {
      recursive = true
    } else if options && (arg == "-v" || arg == "--verbose") {
      verbose = true
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: chmod [-R] [-v] MODE FILE...\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          'R' => recursive = true
          'v' => verbose = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("chmod: unsupported option: \{arg}\n")
        @sys.exit(2)
        return
      }
    } else if mode is None {
      mode = Some(
        parse_mode(arg) catch {
          _ => {
            @stdio.stderr.write("chmod: invalid mode: \{arg}\n")
            @sys.exit(2)
            return
          }
        },
      )
    } else {
      operands.push(arg)
    }
    i += 1
  }
  let selected_mode = match mode {
    Some(value) => value
    None => {
      @stdio.stderr.write("chmod: missing mode\n")
      @sys.exit(2)
      return
    }
  }
  if operands.is_empty() {
    @stdio.stderr.write("chmod: missing operand\n")
    @sys.exit(2)
    return
  }
  let mut failed = false
  for path in operands {
    chmod_path(path, selected_mode, recursive, verbose) catch {
      err => {
        @stdio.stderr.write("chmod: cannot change mode: \{err}\n")
        failed = true
      }
    }
  }
  if failed {
    @sys.exit(1)
  }
}
