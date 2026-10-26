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
  @fs.realpath(path) catch {
    e => raise io_error(e)
  }
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
  let kind = @fs.kind(path, follow_symlink=follow) catch {
    e => raise io_error(e)
  }
  // Size is defined for regular files. Other kinds carry no byte-length claim.
  let len = if kind is Regular { file_len(path) } else { -1L }
  { file_type: file_type(kind), len, dev: None, ino: None, }
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
  let dir = @fs.opendir(path) catch { e => raise io_error(e) }
  defer dir.close()
  let entries : Array[DirEntry] = []
  while (dir.next(include_hidden=true) catch { e => raise io_error(e) })
        is Some(entry) {
    entries.push({ name: entry.name, file_type: None, })
  }
  entries
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
