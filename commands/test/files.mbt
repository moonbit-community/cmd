///|
// Validate the raw trailing separator before canonicalization. Some Darwin
// lookups return a regular target for a file link followed by a slash.
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
async fn test_file(operator : String, value : String) -> Bool {
  if value == "" {
    return false
  }
  try {
    guard test_lookup_path(value) is Some(path) else { return false }
    match operator {
      "-e" | "-a" => @fs.exists(path)
      "-f" => @fs.kind(path) == Regular
      "-d" => @fs.kind(path) == Directory
      "-L" | "-h" => @fs.kind(path, follow_symlink=false) == SymLink
      "-p" => @fs.kind(path) == Pipe
      "-S" => @fs.kind(path) == Socket
      "-b" => @fs.kind(path) == BlockDevice
      "-c" => @fs.kind(path) == CharDevice
      "-s" => {
        // Size follows the target but never opens the entry for reading.
        // Validate before realpath can erase invalid parent components.
        ignore(@fs.kind(path))
        @fs.file_size(@fs.realpath(path)) > 0L
      }
      "-N" => {
        let modified = @fsops.read_file_timestamp(path, ModificationTime)
        let accessed = @fsops.read_file_timestamp(path, AccessTime)
        @fsops.compare_timestamps(modified, accessed) > 0
      }
      "-r" => @fs.can_read(path)
      "-w" => @fs.can_write(path)
      "-x" => @fs.can_execute(path)
      _ => raise TestError("unknown unary operator: '\{operator}'")
    }
  } catch {
    @os_error.OSError(code, ..) if code == @os_error.errno_ENOTSUP =>
      raise TestError(
        "unsupported capability: '\{operator}' metadata for '\{value}'",
      )
    @os_error.OSError(_) => false
    error => raise error
  }
}
