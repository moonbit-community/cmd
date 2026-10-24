///|
priv suberror RealpathError {
  RealpathError(String)
  ReadlinkBoundary(String)
}

///|
priv enum Existence {
  Existing
  AllButLast
  Missing
}

///|
fn slashes(path : String) -> String {
  if @platform.is_windows() {
    path.replace_all(old="\\", new="/")
  } else {
    path
  }
}

///|
fn path_root(path : String) -> String {
  if @platform.is_windows() {
    slashes(@winpath.Path(path).root().to_owned())
  } else {
    "/"
  }
}

///|
fn append_path(parent : String, name : String) -> String {
  parent + (if parent.has_suffix("/") { "" } else { "/" }) + name
}

///|
fn error_text(error : Error) -> String {
  match error {
    RealpathError(message) => message
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      "No such file or directory"
    @os_error.OSError(_) as error if error.is_ENOTDIR() => "Not a directory"
    @os_error.OSError(_) as error if error.is_EACCES() => "Permission denied"
    _ => error.to_string()
  }
}

///|
async fn resolve_path(
  path : String,
  existence : Existence,
  strip : Bool,
) -> String {
  if path.is_empty() {
    raise RealpathError("No such file or directory")
  }
  let cwd = slashes(@fs.realpath("."))
  let input = slashes(path)
  let absolute = if @path.Path(path).is_absolute() {
    if @platform.is_windows() && path_root(input) == "/" {
      path_root(cwd) + input[1:].to_owned()
    } else {
      input
    }
  } else if @platform.is_windows() && input.length() >= 2 && input[1] == ':' {
    let drive_base = slashes(
      @path.Path(input[:2].to_owned()).resolve().to_string(),
    )
    append_path(drive_base, input[2:].to_owned())
  } else {
    append_path(cwd, input)
  }
  let root = path_root(absolute)
  let parts = absolute[root.length():]
    .split("/")
    .filter(p => !p.is_empty())
    .map(p => p.to_owned())
    .collect()
  let mut current = root
  for index, part in parts {
    if part == "." {
      continue
    }
    if part == ".." {
      current = slashes(@path.Path(current).dirname().to_string())
      continue
    }
    let candidate = append_path(current, part)
    if strip && existence is Missing {
      current = candidate
      continue
    }
    let kind = try @fs.kind(candidate, follow_symlink=strip) catch {
      @os_error.OSError(_) as error if error.is_ENOENT() ||
        (existence is Missing && error.is_ENOTDIR()) => None
      error => raise error
    } noraise {
      kind => Some(kind)
    }
    let must_directory = index + 1 < parts.length() || absolute.has_suffix("/")
    match kind {
      None => {
        if existence is Existing || (existence is AllButLast && must_directory) {
          raise RealpathError("No such file or directory")
        }
        current = candidate
      }
      Some(SymLink) if !strip => {
        current = slashes(
          @fs.realpath(candidate) catch {
            error => {
              if existence is Missing ||
                (existence is AllButLast && !must_directory) {
                raise ReadlinkBoundary(candidate)
              }
              raise RealpathError(error_text(error))
            }
          },
        )
        if must_directory &&
          !(existence is Missing) &&
          !(@fs.kind(current) is Directory) {
          raise RealpathError("Not a directory")
        }
      }
      Some(kind) => {
        if must_directory && !(existence is Missing) && !(kind is Directory) {
          raise RealpathError("Not a directory")
        }
        current = candidate
      }
    }
  }
  @platform.normalize_input_separators(current)
}

///|
fn inside(path : String, base : String) -> Bool {
  let path = slashes(path)
  let base = slashes(base)
  let path = if @platform.is_windows() { path.to_lower() } else { path }
  let base = if @platform.is_windows() { base.to_lower() } else { base }
  path == base ||
  path.has_prefix(base + (if base.has_suffix("/") { "" } else { "/" }))
}

///|
fn relative_path(path : String, base : String) -> String {
  let result = @path.Path(path).relative(base=@path.Path(base)).to_string()
  if result.is_empty() {
    "."
  } else {
    result
  }
}

///|
async fn main {
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("canonicalize-existing", short='e'),
    @cli.flag("canonicalize-missing", short='m'),
    @cli.flag("canonicalize", short='E'),
    @cli.flag("strip", short='s'),
    @cli.flag("no-symlinks"),
    @cli.flag("quiet", short='q'),
    @cli.flag("zero", short='z'),
    @cli.option("relative-to"),
    @cli.option("relative-base"),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(kind=MissingOptionValue, option~, ..) if option ==
      "relative-to" ||
      option == "relative-base" => {
      @stdio.stderr.write(
        "realpath: option '--\{option}' requires an argument\nTry 'realpath --help' for more information.\n",
      )
      @sys.exit(1)
      return
    }
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("realpath: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: realpath [OPTION]... NAME...\n" +
      "  -e, --canonicalize-existing  require every component to exist\n" +
      "  -E, --canonicalize           allow a missing final component (default)\n" +
      "  -m, --canonicalize-missing   allow missing or non-directory components\n" +
      "  -s, --strip, --no-symlinks   do not expand symbolic links\n" +
      "      --relative-to=DIR        print relative to DIR\n" +
      "      --relative-base=DIR      use relative output only inside DIR\n" +
      "  -q, --quiet                 suppress operand errors\n" +
      "  -z, --zero                  terminate output with NUL\n" +
      "      --help                  display this help and exit\n" +
      "      --version               display version and exit\n",
    )
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("realpath \{command_version}\n")
    return
  }
  if parsed.operands.is_empty() {
    @stdio.stderr.write(
      "realpath: missing operand\nTry 'realpath --help' for more information.\n",
    )
    @sys.exit(1)
    return
  }
  let existence = match
    parsed.last_occurrence([
      "canonicalize-existing", "canonicalize-missing", "canonicalize",
    ]) {
    Some("canonicalize-existing") => Existing
    Some("canonicalize-missing") => Missing
    _ => AllButLast
  }
  let strip = parsed.contains("strip") || parsed.contains("no-symlinks")
  let base_arg = parsed.last_value("relative-base")
  let to_arg = match parsed.last_value("relative-to") {
    Some(_) as value => value
    None => base_arg
  }
  let mut relative_to : String? = None
  let mut relative_base : String? = None
  for (argument, is_base) in [(to_arg, false), (base_arg, true)] {
    if argument is Some(argument) {
      let value = resolve_path(argument, existence, strip) catch {
        ReadlinkBoundary(_) => {
          @stdio.stderr.write(
            "realpath: unsupported capability: unresolved symbolic-link target (readlink)\n",
          )
          @sys.exit(2)
          return
        }
        error => {
          @stdio.stderr.write("realpath: \{argument}: \{error_text(error)}\n")
          @sys.exit(1)
          return
        }
      }
      if existence is Existing && !(@fs.kind(value) is Directory) {
        @stdio.stderr.write("realpath: \{argument}: Not a directory\n")
        @sys.exit(1)
        return
      }
      if is_base {
        relative_base = Some(value)
      } else {
        relative_to = Some(value)
      }
    }
  }
  if relative_base is Some(base) && relative_to is Some(to) && !inside(to, base) {
    relative_to = None
  }
  let separator = if parsed.contains("zero") { "\u0000" } else { "\n" }
  let mut status = 0
  for operand in parsed.operands {
    let value = resolve_path(operand, existence, strip) catch {
      ReadlinkBoundary(_) => {
        if !parsed.contains("quiet") {
          @stdio.stderr.write(
            "realpath: unsupported capability: unresolved symbolic-link target (readlink)\n",
          )
        }
        status = 2
        continue
      }
      error => {
        if !parsed.contains("quiet") {
          @stdio.stderr.write("realpath: \{operand}: \{error_text(error)}\n")
        }
        status = status.max(1)
        continue
      }
    }
    let relative = relative_base
      .map(base => inside(value, base))
      .unwrap_or(true)
    let output = if relative && relative_to is Some(to) {
      relative_path(value, to)
    } else {
      value
    }
    @stdio.stdout.write(output + separator)
  }
  if status != 0 {
    @sys.exit(status)
  }
}
