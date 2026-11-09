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
