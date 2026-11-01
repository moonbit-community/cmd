///|
pub suberror TemporaryError {
  TemporaryError(String)
}

///|
/// An exclusively created temporary directory. Close files before `close`.
/// Cleanup errors propagate; callers explicitly choose their error precedence.
struct Directory {
  path : String
  mut closed : Bool
}

///|
pub async fn Directory::new(
  prefix~ : String,
  parent~ : String? = None,
) -> Directory {
  guard !prefix.contains("/") && !prefix.contains("\\") else {
    raise TemporaryError("temporary prefix must be a file name")
  }
  guard parent is Some(parent) else {
    return { path: @fs.tmpdir(prefix~), closed: false, }
  }
  for _ in 0..<32 {
    let random = match @env.rand(16) {
      Some(bytes) => @hex.encode(bytes[:])
      None => raise TemporaryError("secure random source is unavailable")
    }
    let path = parent + "/" + prefix + random
    try @fs.mkdir(path, permission=0o700) catch {
      @os_error.OSError(_) as error if error.is_EEXIST() => ()
      error => raise error
    } noraise {
      _ => return { path, closed: false, }
    }
  }
  raise TemporaryError("cannot create an exclusive temporary directory")
}

///|
pub fn Directory::path(self : Directory) -> String {
  self.path
}

///|
/// Idempotent after success. A failed cleanup remains retryable.
pub async fn Directory::close(self : Directory) -> Unit {
  if !self.closed {
    @fs.rmdir(self.path, recursive=true)
    self.closed = true
  }
}
