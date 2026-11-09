///|
/// Atomically create the first unoccupied numbered sibling and return its path
/// and open handle. The original path is attempted first, followed by `.1`,
/// `.2`, and so on. Commands retain ownership of whether this naming rule is
/// appropriate for their upstream.
async fn open_unique_numbered_output(
  path : String,
  permission~ : Int32 = 0o644,
) -> (String, @fs.File) {
  let path = @platform.normalize_input_separators(path)
  for suffix = 0; ; suffix = suffix + 1 {
    let candidate = if suffix == 0 {
      path
    } else {
      path + "." + suffix.to_string()
    }
    let file = @fs.open(
      candidate,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission~,
    ) catch {
      @os_error.OSError(_) as err if err.is_EEXIST() => continue
      err => raise err
    }
    return (candidate, file)
  }
}

///|
async fn cleanup_file_if_exists(path : String) -> Unit {
  try @fs.kind(path, follow_symlink=false) catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => return
    err => raise err
  } noraise {
    Directory =>
      raise @fsops.FsOpError("temporary path is a directory: '\{path}'")
    _ => @fs.remove(path)
  }
}
