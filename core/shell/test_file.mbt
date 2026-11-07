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
      "-s" => @fs.file_size(path) > 0L
      _ => false
    }
  } catch {
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
