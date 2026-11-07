///|
fn test_path(value : String, context : Context) -> String {
  if value == "" || @path.Path(value).is_absolute() {
    value
  } else {
    context.cwd + "/" + value
  }
}

///|
// A POSIX trailing separator requires a directory, including through links.
// Some Darwin metadata calls return a file link's target kind despite that
// separator. Validate the raw lookup before resolving a valid directory;
// resolution also prevents -L/-h from observing its final link instead.
async fn test_lookup_path(path : String) -> String? {
  if !(@async.platform is Windows) && path.has_suffix("/") {
    if @fs.kind(path) != Directory {
      None
    } else {
      Some(@fs.realpath(path))
    }
  } else {
    Some(path)
  }
}

///|
async fn test_file(
  operator : String,
  value : String,
  context : Context,
) -> Bool {
  if value == "" {
    return false
  }
  try {
    guard test_lookup_path(test_path(value, context)) is Some(path) else {
      return false
    }
    match operator {
      "-e" => @fs.exists(path)
      "-f" => @fs.kind(path) == Regular
      "-d" => @fs.kind(path) == Directory
      "-b" => @fs.kind(path) == BlockDevice
      "-c" => @fs.kind(path) == CharDevice
      "-p" => @fs.kind(path) == Pipe
      "-S" => @fs.kind(path) == Socket
      "-L" | "-h" => @fs.kind(path, follow_symlink=false) == SymLink
      "-r" => @fs.can_read(path)
      "-w" => @fs.can_write(path)
      "-x" => @fs.can_execute(path)
      "-s" => {
        // Validate the raw lookup before canonicalization can remove a
        // non-directory parent component. Size itself must follow the target.
        ignore(@fs.kind(path))
        @fs.file_size(@fs.realpath(path)) > 0L
      }
      _ => false
    }
  } catch {
    @os_error.OSError(code, ..) if operator == "-s" &&
      code == @os_error.errno_ENOTSUP =>
      raise ShellError(
        "test: '-s' target size is unavailable through the public filesystem API: '\{value}'",
      )
    @os_error.OSError(_) => false
    err => raise err
  }
}

///|
async fn test_mtime(value : String, context : Context) -> (Int64, Int32)? {
  if value == "" {
    return None
  }
  try {
    guard test_lookup_path(test_path(value, context)) is Some(path) else {
      return None
    }
    Some(@fs.mtime(path))
  } catch {
    @os_error.OSError(_) => None
    err => raise err
  }
}
