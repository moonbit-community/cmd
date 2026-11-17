///|
/// A static-file root that can be shared by concurrent request handlers.
/// Each instance keeps its own canonical root and holds no open resources.
pub struct Directory {
  priv root : String
}

///|
/// Resolve and validate a directory before handling requests.
pub async fn Directory::Directory(path : String) -> Directory {
  let root = @fs.realpath(path)
  guard @fs.kind(root) is Directory else { fail("not a directory: " + path) }
  { root, }
}
