///|
pub fn block_size(text : String) -> Int64 raise {
  guard !text.is_empty() && text.iter().all(ch => ch >= '0' && ch <= '9') else {
    raise Failure("invalid block size")
  }
  let size = @string.parse_int64(text)
  guard size > 0 else { raise Failure("invalid block size") }
  size
}

///|
pub async fn apparent(path : String, follow~ : Bool) -> Int64 {
  guard @fs.kind(path, follow_symlink=follow) is Regular else {
    raise Failure("apparent size requires a regular file")
  }
  @fs.file_size(if follow { @fs.realpath(path) } else { path })
}

///|
pub fn blocks(bytes : Int64, unit : Int64) -> Int64 {
  bytes / unit + (if bytes % unit == 0L { 0L } else { 1L })
}
