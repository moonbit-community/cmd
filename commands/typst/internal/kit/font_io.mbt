// Font discovery uses async/fs on native and wasm: real offset reads and
// block transfers across the wasm host boundary, not x/fs's byte-at-a-time
// whole-file transfer. Parsing and the resulting FontStore stay synchronous.

///|
async fn font_read_range(file : @fs.File, offset : Int64, len : Int32) -> Bytes {
  let buffer = FixedArray::make(len, b'\x00')
  let n = file.read_at(buffer, position=offset)
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  if n == len {
    bytes
  } else {
    bytes[:n].to_owned()
  }
}

///|
async fn font_stat_kind(
  path : String,
  follow_symlink~ : Bool = true,
) -> @platform.FileKind {
  match @fs.kind(path, follow_symlink~) {
    Regular => File
    Directory => Dir
    SymLink => Symlink
    _ => Other
  }
}

///|
async fn font_read_dir_entries(path : String) -> Array[@platform.DirEntry] {
  let dir = @fs.opendir(path)
  defer dir.close()
  let entries : Array[@platform.DirEntry] = []
  while dir.next(include_hidden=true, include_special=false) is Some(entry) {
    // Non-directories still need lstat to distinguish files and symlinks.
    entries.push({
      name: entry.name,
      kind: if entry.is_dir {
        Some(Dir)
      } else {
        None
      },
    })
  }
  entries
}
