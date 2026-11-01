///|
/// Resolve repository-owned definitions independently of the caller's directory.
pub async fn repository_root(start~ : String = ".") -> String {
  let mut current = @fs.realpath(start)
  for ;; {
    if @fs.exists(current + "/moon.work") &&
      @fs.exists(current + "/tests/moon.mod") {
      return current
    }
    let parent = @path.Path(current).dirname().normalize().to_string()
    guard parent != current else {
      fail("cannot locate cmd workspace root from " + start)
    }
    current = parent
  }
}

///|
pub async fn repository_path(relative : String) -> String {
  let path = @path.Path(relative)
  if path.is_absolute() {
    path.normalize().to_string()
  } else {
    @path.Path(repository_root()).join(path).normalize().to_string()
  }
}
