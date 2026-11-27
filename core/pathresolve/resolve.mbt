///|
pub suberror RealpathError {
  RealpathError(String)
  ReadlinkBoundary(String)
}

///|
pub(all) enum Existence {
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
pub fn error_text(error : Error) -> String {
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
pub async fn resolve_path(
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
        current = if !strip && @platform.is_windows() {
          slashes(@fs.realpath(candidate))
        } else {
          candidate
        }
      }
    }
  }
  @platform.normalize_input_separators(current)
}

///|
pub fn inside(path : String, base : String) -> Bool {
  let path = slashes(path)
  let base = slashes(base)
  let path = if @platform.is_windows() { path.to_lower() } else { path }
  let base = if @platform.is_windows() { base.to_lower() } else { base }
  path == base ||
  path.has_prefix(base + (if base.has_suffix("/") { "" } else { "/" }))
}
