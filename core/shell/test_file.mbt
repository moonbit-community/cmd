///|
fn test_path(value : String, context : Context) -> String {
  if value == "" || @path.Path(value).is_absolute() {
    value
  } else {
    context.cwd + "/" + value
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
  let path = test_path(value, context)
  try {
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
        let kind = @fs.kind(path)
        // Some macOS versions report a regular symlink target even with a
        // trailing slash. POSIX still requires that operand to be a directory.
        if !(@async.platform is Windows) &&
          path.has_suffix("/") &&
          kind != Directory {
          false
        } else {
          @fs.file_size(@fs.realpath(path)) > 0L
        }
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
  Some(@fs.mtime(test_path(value, context))) catch {
    @os_error.OSError(_) => None
    err => raise err
  }
}
