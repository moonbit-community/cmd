///|
/// A kind observation for one visit. Create a new entry when revisiting a path;
/// this is not a filesystem snapshot or an identity across command effects.
pub struct Entry {
  priv path : String
  kind : @fs.FileKind
}

///|
pub(all) enum SizeSource {
  OpenFile
  ResolvedPath
}

///|
pub fn Entry::known(path : String, kind : @fs.FileKind) -> Entry {
  { path, kind, }
}

///|
pub async fn Entry::read(
  path : String,
  follow_symlink~ : Bool = false,
) -> Entry {
  { path, kind: @fs.kind(path, follow_symlink~), }
}

///|
/// Query only when the caller requests size. The source preserves the caller's
/// existing open-file or resolved-path operation and its error ordering.
pub async fn Entry::regular_size(self : Entry, source : SizeSource) -> Int64? {
  if self.kind != Regular {
    return None
  }
  Some(
    match source {
      OpenFile => {
        let file = @fs.open(self.path, mode=ReadOnly)
        defer file.close()
        file.size()
      }
      ResolvedPath => @fs.file_size(@fs.realpath(self.path))
    },
  )
}

///|
/// Reading names never requests kind, size or timestamps. Ordering, filtering,
/// recursion and error policy belong to the command.
/// `include_hidden` follows the filesystem API: dot-prefixed names on Unix,
/// the hidden file attribute on Windows.
pub async fn read_directory(
  path : String,
  include_hidden~ : Bool = true,
) -> Array[String] {
  let directory = @fs.opendir(path)
  defer directory.close()
  let names : Array[String] = []
  while directory.next(include_hidden~) is Some(entry) {
    names.push(entry.name)
  }
  names
}
