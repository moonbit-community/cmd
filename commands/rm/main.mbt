///|
priv struct RmOptions {
  recursive : Bool
  force : Bool
  empty_directories : Bool
  verbose : Bool
  interactive : Bool
}

///|
priv enum Removal {
  Visit(String)
  FinishDirectory(String)
}

///|
fn interaction_args(args : ArrayView[String]) -> Array[String] {
  let result : Array[String] = []
  let mut literal = false
  for arg in args {
    if literal {
      result.push(arg)
      continue
    }
    if arg == "--" {
      literal = true
      result.push(arg)
    } else if arg == "--interactive" {
      result.push("--interactive=always")
    } else if arg.has_prefix("-") && !arg.has_prefix("--") && arg != "-" {
      for option in arg[1:] {
        result.push(
          match option {
            'i' => "--interactive=always"
            'I' => "--interactive=once"
            _ => "-" + option.to_string()
          },
        )
      }
    } else {
      result.push(arg)
    }
  }
  result
}

///|
fn interactive_choice(value : String) -> String? {
  let values = [
    ("never", "never"),
    ("no", "never"),
    ("none", "never"),
    ("once", "once"),
    ("always", "always"),
    ("yes", "always"),
  ]
  let matches = values.filter(pair => pair.0.has_prefix(value))
  guard matches.get(0) is Some(first) else { return None }
  if matches.all(pair => pair.1 == first.1) {
    Some(first.1)
  } else {
    None
  }
}

///|
async fn confirm(message : String) -> Bool {
  @stdio.stderr.write("rm: \{message}? ")
  let mut first = true
  let mut accepted = false
  while @stdio.stdin.read_some(max_len=1) is Some(bytes) {
    let byte = bytes[0]
    if first {
      accepted = byte is (b'y' | b'Y')
      first = false
    }
    if byte == b'\n' {
      break
    }
  }
  accepted
}

///|
fn quote_path(path : String) -> String {
  if path.contains("'") &&
    !path.contains("\"") &&
    !path.contains("\\") &&
    !path.contains("$") &&
    !path.iter().any(c => c.to_int() < 32 || c.to_int() == 96) {
    return "\"" + path + "\""
  }
  let output = StringBuilder()
  output.write_char('\'')
  for char in path {
    match char {
      '\'' => output.write_string("'\\''")
      '\n' => output.write_string("'$'\\n''")
      '\r' => output.write_string("'$'\\r''")
      '\t' => output.write_string("'$'\\t''")
      _ => output.write_char(char)
    }
  }
  output.write_char('\'')
  output.to_string()
}

///|
fn remove_error(error : Error) -> String {
  match error {
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      "No such file or directory"
    @os_error.OSError(_) as error if error.is_ENOTDIR() => "Not a directory"
    @os_error.OSError(_) as error if error.is_EACCES() => "Permission denied"
    _ => error.to_string()
  }
}

///|
async fn report_error(path : String, error : Error, directory : Bool) -> Unit {
  let denied = match error {
    @os_error.OSError(_) as error => error.is_EACCES()
    _ => false
  }
  let message = if directory && !denied {
    let nonempty = try
      !@fs.readdir(path, include_hidden=true, sort=false).is_empty()
    catch {
      _ => false
    }
    if nonempty {
      "Directory not empty"
    } else {
      remove_error(error)
    }
  } else {
    remove_error(error)
  }
  @stdio.stderr.write("rm: cannot remove \{quote_path(path)}: \{message}\n")
}

///|
async fn file_type(path : String, kind : @fs.FileKind) -> String {
  match kind {
    Regular =>
      if @fs.file_size(path) == 0L {
        "regular empty file"
      } else {
        "regular file"
      }
    Directory => "directory"
    SymLink => "symbolic link"
    Socket => "socket"
    Pipe => "fifo"
    BlockDevice => "block special file"
    CharDevice => "character special file"
    Unknown => "weird file"
  }
}

///|
async fn item_prompt(
  path : String,
  kind : @fs.FileKind,
  descend : Bool,
) -> Bool {
  let write_protected = !(kind is SymLink) && !@fs.can_write(path)
  if descend {
    confirm(
      "descend into " +
      (if write_protected { "write-protected " } else { "" }) +
      "directory " +
      quote_path(path),
    )
  } else {
    confirm(
      "remove " +
      (if write_protected { "write-protected " } else { "" }) +
      file_type(path, kind) +
      " " +
      quote_path(path),
    )
  }
}

///|
async fn remove_operand(operand : String, options : RmOptions) -> Bool {
  let pending : Array[Removal] = [Visit(operand)]
  let mut failed = false
  while pending.pop() is Some(work) {
    let path = match work {
      Visit(path) | FinishDirectory(path) => path
    }
    if work is FinishDirectory(_) {
      if options.interactive && !item_prompt(path, Directory, false) {
        continue
      }
      @fs.rmdir(path) catch {
        error => {
          report_error(path, error, true)
          failed = true
          continue
        }
      }
      if options.verbose {
        @stdio.stdout.write("removed directory \{quote_path(path)}\n")
      }
      continue
    }
    let kind = @fsops.kind_if_exists(path) catch {
      error => {
        report_error(path, error, false)
        failed = true
        continue
      }
    }
    match kind {
      None =>
        if !options.force {
          @stdio.stderr.write(
            "rm: cannot remove \{quote_path(path)}: No such file or directory\n",
          )
          failed = true
        }
      Some(Directory) => {
        if !options.recursive && !options.empty_directories {
          @stdio.stderr.write(
            "rm: cannot remove \{quote_path(path)}: Is a directory\n",
          )
          failed = true
          continue
        }
        let entries = @fs.readdir(
          path,
          include_hidden=true,
          include_special=false,
          sort=false,
        ) catch {
          error => {
            report_error(path, error, true)
            failed = true
            continue
          }
        }
        if options.recursive && !entries.is_empty() {
          if options.interactive && !item_prompt(path, Directory, true) {
            continue
          }
          pending.push(FinishDirectory(path))
          for index = entries.length() - 1; index >= 0; index = index - 1 {
            pending.push(Visit(@fsops.join(path, entries[index])))
          }
        } else {
          if options.interactive && !entries.is_empty() {
            @stdio.stderr.write(
              "rm: cannot remove \{quote_path(path)}: Is a directory\n",
            )
            failed = true
            continue
          }
          if options.interactive && !item_prompt(path, Directory, false) {
            continue
          }
          @fs.rmdir(path) catch {
            error => {
              report_error(path, error, true)
              failed = true
              continue
            }
          }
          if options.verbose {
            @stdio.stdout.write("removed directory \{quote_path(path)}\n")
          }
        }
      }
      Some(kind) => {
        if options.interactive && !item_prompt(path, kind, false) {
          continue
        }
        @fs.remove(path) catch {
          error => {
            report_error(path, error, false)
            failed = true
            continue
          }
        }
        if options.verbose {
          @stdio.stdout.write("removed \{quote_path(path)}\n")
        }
      }
    }
  }
  !failed
}

///|
async fn main {
  let parsed = @cli.parse(interaction_args(@env.args()[1:]), [
    @cli.flag("recursive", short='r'),
    @cli.flag("recursive", short='R'),
    @cli.flag("force", short='f'),
    @cli.flag("dir", short='d'),
    @cli.flag("verbose", short='v'),
    @cli.option("interactive"),
    @cli.flag("preserve-root"),
    @cli.flag("no-preserve-root"),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("rm: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: rm [OPTION]... FILE...\n" +
      "  -f, --force             ignore missing files; never prompt\n" +
      "  -i                      prompt for each removal using stdin\n" +
      "  -I                      prompt once for recursion or more than three operands\n" +
      "      --interactive[=WHEN] never, once or always (default with option)\n" +
      "  -r, -R, --recursive     remove directory trees without following symlinks\n" +
      "  -d, --dir               remove empty directories\n" +
      "  -v, --verbose           print removed paths\n" +
      "      --preserve-root     protect filesystem roots (default)\n" +
      "      --no-preserve-root  disable root protection\n" +
      "      --help              display this help and exit\n" +
      "      --version           display version and exit\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("rm 0.2.2\n")
    return
  }
  let mut preserve_root = true
  let mut force = false
  let mut always = false
  let mut once = false
  let values = parsed.values("interactive")
  let mut value_index = 0
  for option in parsed.order {
    match option {
      "preserve-root" => preserve_root = true
      "no-preserve-root" => preserve_root = false
      "force" => {
        force = true
        always = false
        once = false
      }
      "interactive" => {
        let value = values[value_index]
        value_index += 1
        match interactive_choice(value) {
          Some("never") => {
            always = false
            once = false
          }
          Some("once") => {
            always = false
            once = true
            force = false
          }
          Some(_) => {
            always = true
            once = false
            force = false
          }
          None => {
            let reason = if value.is_empty() { "ambiguous" } else { "invalid" }
            @stdio.stderr.write(
              "rm: \{reason} argument '\{value}' for '--interactive'\n",
            )
            @stdio.stderr.write(
              "Valid arguments are:\n  - 'never', 'no', 'none'\n  - 'once'\n  - 'always', 'yes'\n",
            )
            @stdio.stderr.write("Try 'rm --help' for more information.\n")
            @sys.exit(1)
            return
          }
        }
      }
      _ => ()
    }
  }
  let options : RmOptions = {
    recursive: parsed.contains("recursive"),
    force,
    empty_directories: parsed.contains("dir"),
    verbose: parsed.contains("verbose"),
    interactive: always,
  }
  let paths = parsed.operands
  if paths.is_empty() {
    if force {
      return
    }
    @stdio.stderr.write(
      "rm: missing operand\nTry 'rm --help' for more information.\n",
    )
    @sys.exit(1)
    return
  }
  if once && (options.recursive || paths.length() > 3) {
    let noun = if paths.length() == 1 { "argument" } else { "arguments" }
    let recursive = if options.recursive { " recursively" } else { "" }
    if !confirm("remove \{paths.length()} \{noun}\{recursive}") {
      return
    }
  }
  let mut failed = false
  for path in paths {
    if @fsops.protects_removal_operand(path, preserve_root~) {
      @stdio.stderr.write("rm: refusing to remove protected path '\{path}'\n")
      failed = true
      continue
    }
    if !remove_operand(path, options) {
      failed = true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
