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
pub fn blocks(bytes : Int64, unit : Int64) -> Int64 {
  bytes / unit + (if bytes % unit == 0L { 0L } else { 1L })
}

///|
pub fn add(left : Int64, right : Int64) -> Int64 raise {
  guard right <= 9223372036854775807L - left else {
    raise Failure("total size overflow")
  }
  left + right
}

///|
pub(all) enum Detail {
  Directories
  All
  Summary
}

///|
pub(all) suberror WalkError {
  UnreadableDirectory
}

///|
pub async fn measure(
  operands : ArrayView[String],
  detail~ : Detail,
  follow~ : Bool,
  count_links~ : Bool,
  inodes~ : Bool,
  emit~ : async (String, Int64) -> Unit,
  report~ : async (String, Error) -> Unit,
) -> Int64 {
  let windows = @platform.is_windows()
  if windows && !count_links && operands.length() > 1 {
    raise Failure("multiple operands on Windows require -l to count each name")
  }
  let seen : Array[@xfs.FileIdentity] = []
  let ancestors : Array[@xfs.FileIdentity] = []
  async fn visit(path : String, is_operand : Bool) -> Int64 {
    let (kind, own, identity) = try {
      let kind = @fs.kind(path, follow_symlink=follow)
      if windows && kind is Directory && (!count_links || follow) {
        raise Failure("Windows directory traversal requires -l without -L")
      }
      let identity = if (
          !count_links &&
          (kind is Directory || !is_operand || operands.length() > 1)
        ) ||
        (follow && kind is Directory) {
        guard @xfs.identity(path, follow_symlink=follow) is Some(id) else {
          raise Failure("file identity unavailable")
        }
        if (!count_links && seen.contains(id)) ||
          (kind is Directory && ancestors.contains(id)) {
          return 0L
        }
        Some(id)
      } else {
        None
      }
      let own = if inodes {
        1L
      } else if kind is Regular || kind is SymLink {
        @fs.file_size(if follow { @fs.realpath(path) } else { path })
      } else {
        // GNU du counts only entries with a usable POSIX st_size.
        0L
      }
      (kind, own, identity)
    } catch {
      error => {
        report(path, error)
        return 0L
      }
    }
    if !count_links && identity is Some(id) {
      seen.push(id)
    }
    let mut size = own
    if kind is Directory {
      if follow && identity is Some(id) {
        ancestors.push(id)
      }
      let children = @fs.readdir(path, include_hidden=true) catch {
        @os_error.OsError(AccessDenied, ..) => {
          report(path, UnreadableDirectory)
          []
        }
        error => {
          report(path, error)
          []
        }
      }
      for name in children {
        let child = (if path.has_suffix("/") { path } else { path + "/" }) +
          name
        size = add(size, visit(child, false))
      }
      if follow && identity is Some(_) {
        ignore(ancestors.pop())
      }
    }
    if is_operand ||
      detail is All ||
      (detail is Directories && kind is Directory) {
      emit(path, size)
    }
    size
  }
  let mut total = 0L
  for path in operands {
    total = add(total, visit(path, true))
  }
  total
}
