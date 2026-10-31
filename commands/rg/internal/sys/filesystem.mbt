///|
// Strategy: rg-directory-observations

///|
pub async fn File::open(path : String) -> File {
  { inner: @fs.open(path, mode=ReadOnly) catch { e => raise io_error(e) }, }
}

///|
pub async fn File::read(
  self : File,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Int32 {
  self.inner.read(buf, offset=start, max_len=len) catch {
    e => raise io_error(e)
  }
}

///|
pub fn File::close(self : File) -> Unit {
  self.inner.close()
}

///|
/// The open handle already carries this observation; no path stat is needed.
pub fn File::is_regular(self : File) -> Bool {
  self.inner.kind() is Regular
}

///|
pub async fn read_file(path : String) -> Bytes {
  @fs.read_file(path).binary() catch {
    e => raise io_error(e)
  }
}

///|
pub async fn write_file(path : String, data : Bytes) -> Unit {
  @fs.write_file(path, data) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn create_dir_all(path : String) -> Unit {
  @fs.mkdir(path, recursive=true, allow_exist=true) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn remove_dir_all(path : String) -> Unit {
  @fs.rmdir(path, recursive=true) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn remove_file(path : String) -> Unit {
  @fs.remove(path) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn symlink(target : String, link : String) -> Unit {
  @fs.symlink(target~, link) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn path_exists(path : String) -> Bool {
  @fs.exists(path) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn canonicalize(path : String) -> String {
  let resolved = @fs.realpath(path) catch { e => raise io_error(e) }
  normalize_path(resolved)
}

///|
pub async fn file_len(path : String) -> Int64 {
  // The path size API reports the link entry on some hosts. Resolve through
  // the public realpath API before asking for a followed regular file's size.
  let resolved = @fs.realpath(path) catch { e => raise io_error(e) }
  @fs.file_size(resolved) catch {
    e => raise io_error(e)
  }
}

///|
fn file_type(kind : @fs.FileKind) -> FileType {
  match kind {
    Regular => File
    Directory => Dir
    SymLink => Symlink
    _ => Other
  }
}

///|
async fn stat(path : String, follow : Bool) -> Metadata {
  let entry = @fswalk.Entry::read(path, follow_symlink=follow) catch {
    e => raise io_error(e)
  }
  let len = entry.regular_size(ResolvedPath) catch { e => raise io_error(e) }
  { file_type: file_type(entry.kind), len: len.unwrap_or(-1L), }
}

///|
pub async fn metadata(path : String) -> Metadata {
  stat(path, true)
}

///|
pub async fn symlink_metadata(path : String) -> Metadata {
  stat(path, false)
}

///|
pub async fn read_dir(path : String) -> Array[DirEntry] {
  try {
    let dir = @fs.opendir(path)
    defer dir.close()
    let entries : Array[DirEntry] = []
    while dir.next(include_hidden=true) is Some(entry) {
      entries.push({ name: entry.name, is_dir: entry.is_dir, })
    }
    entries
  } catch {
    e => raise io_error(e)
  }
}

///|
/// Reuse the directory observation without asking for size or a resolved path.
/// Public DirectoryEntry exposes no full kind or inode, so unknown kinds are
/// queried without following links and identities remain unavailable.
pub async fn DirEntry::file_type(self : DirEntry, path : String) -> FileType {
  if self.is_dir {
    Dir
  } else {
    file_type(@fs.kind(path, follow_symlink=false)) catch {
      e => raise io_error(e)
    }
  }
}

///|
pub async fn file_times(path : String) -> FileTimes {
  let (msec, mnsec) = @fs.mtime(path) catch { e => raise io_error(e) }
  let (asec, ansec) = @fs.atime(path) catch { e => raise io_error(e) }
  {
    modified: Some(msec * 1000000000L + mnsec.to_int64()),
    accessed: Some(asec * 1000000000L + ansec.to_int64()),
    created: None,
  }
}

///|
pub fn read_link(_path : String) -> String raise IOError {
  raise IOError::other(
    Unsupported,
    "readlink requires a released public MoonBit API",
  )
}
