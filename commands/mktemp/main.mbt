///|
priv suberror MktempError {
  MktempError(String)
}

///|
fn random_hex(length : Int) -> String raise MktempError {
  guard @env.rand(length) is Some(bytes) else {
    raise MktempError("mktemp: secure random source is unavailable")
  }
  let digits = "0123456789abcdef"
  let output = StringBuilder()
  for byte in bytes {
    output.write_char(digits[byte.to_int() & 0x0F].unsafe_to_char())
  }
  output.to_string()
}

///|
fn fill_template(template : String) -> String raise MktempError {
  let chars : Array[Char] = template.iter().collect()
  let mut first = chars.length()
  while first > 0 && chars[first - 1] == 'X' {
    first -= 1
  }
  if chars.length() - first < 3 {
    raise MktempError("mktemp: template must end in at least 3 X's")
  }
  let replacement = random_hex(chars.length() - first)
  let output = StringBuilder()
  for index, char in chars {
    if index < first {
      output.write_char(char)
    } else {
      output.write_char(replacement[index - first].unsafe_to_char())
    }
  }
  output.to_string()
}

///|
fn default_template(directory : Bool) -> String {
  let root = @env.get_env_var("TMPDIR").unwrap_or("/tmp")
  if directory {
    root + "/tmp.XXXXXX"
  } else {
    root + "/tmp.XXXXXX"
  }
}

///|
async fn create_file(path : String) -> Bool raise MktempError {
  try {
    let file = @fs.open(
      path,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission=0o600,
    )
    file.close()
    true
  } catch {
    @os_error.OSError(_) as error if error.is_EEXIST() => false
    _ => raise MktempError("mktemp: cannot create temporary file")
  }
}

///|
async fn create_directory(path : String) -> Bool raise MktempError {
  try {
    @fs.mkdir(path, permission=0o700)
    true
  } catch {
    @os_error.OSError(_) as error if error.is_EEXIST() => false
    _ => raise MktempError("mktemp: cannot create temporary directory")
  }
}

///|
async fn create_unique(
  template : String,
  directory : Bool,
) -> String raise MktempError {
  for _ in 0..<100 {
    let candidate = fill_template(template)
    let created = if directory {
      create_directory(candidate)
    } else {
      create_file(candidate)
    }
    if created {
      return candidate
    }
  }
  raise MktempError("mktemp: failed to create a unique name after 100 attempts")
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("directory", short='d'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("mktemp: \{message}: '\{option}'\n")
      @sys.exit(1)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: mktemp [-d] [TEMPLATE]\nCreate a uniquely named temporary file or directory.\n",
    )
    return
  }
  if parsed.operands.length() > 1 {
    @stdio.stderr.write("mktemp: too many templates\n")
    @sys.exit(1)
    return
  }
  let directory = parsed.contains("directory")
  let template = if parsed.operands.is_empty() {
    default_template(directory)
  } else {
    parsed.operands[0]
  }
  let result = create_unique(template, directory) catch {
    MktempError(message) => {
      @stdio.stderr.write("\{message}\n")
      @sys.exit(1)
      return
    }
  }
  @stdio.stdout.write(result + "\n")
}
