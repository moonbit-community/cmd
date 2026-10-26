///|
/// Returns true if `c` is a path separator on the current platform.
///
/// This port only implements Unix semantics, where `/` is the only separator.
fn is_separator(c : Char) -> Bool {
  c == '/'
}

///|
/// The final component of the path, if it is a normal file.
///
/// If the path terminates in `..`, or consists solely of a root of prefix,
/// file_name will return `None`.
fn file_name(path : Bytes) -> Bytes? {
  if path.length() == 0 {
    return None
  }
  let mut last_slash = 0
  for i = path.length() - 1; i >= 0; i = i - 1 {
    if path[i] == b'/' {
      last_slash = i + 1
      break
    }
  }
  let got = path[last_slash:].to_owned()
  if got == b".." {
    return None
  }
  Some(got)
}

///|
/// Return a file extension given a path's file name.
///
/// Note that this does NOT match the semantics of std::path::Path::extension.
/// Namely, the extension includes the `.` and matching is otherwise more
/// liberal. Specifically, the extension is:
///
/// * None, if the file name given is empty;
/// * None, if there is no embedded `.`;
/// * Otherwise, the portion of the file name starting with the final `.`.
///
/// e.g., A file name of `.rs` has an extension `.rs`.
fn file_name_ext(name : Bytes) -> Bytes? {
  if name.length() == 0 {
    return None
  }
  for i = name.length() - 1; i >= 0; i = i - 1 {
    if name[i] == b'.' {
      return Some(name[i:].to_owned())
    }
  }
  None
}

///|
/// Normalizes a path to use `/` as a separator everywhere, even on platforms
/// that recognize other characters as separators.
///
/// On Unix (the only platform supported by this port), this is the identity.
fn normalize_path(path : Bytes) -> Bytes {
  path
}
