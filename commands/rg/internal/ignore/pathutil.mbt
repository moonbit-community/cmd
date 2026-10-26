// Port of `ignore/src/pathutil.rs` (Unix behavior).

///|
/// Returns true if and only if this path is considered to be hidden, i.e.,
/// its base name starts with a `.`.
fn is_hidden_path(path : String) -> Bool {
  match file_name(path) {
    Some(name) => name.has_prefix(".")
    None => false
  }
}

///|
/// Returns true if and only if this directory entry is considered to be
/// hidden.
fn is_hidden_entry(dent : DirEntry) -> Bool {
  is_hidden_path(dent.path())
}

///|
/// Strip `prefix` from the `path` and return the remainder (byte-wise).
///
/// If `path` doesn't have a prefix `prefix`, then return `None`.
fn strip_prefix(prefix : String, path : String) -> String? {
  if path.has_prefix(prefix) {
    Some(path.unsafe_substring(start=prefix.length(), end=path.length()))
  } else {
    None
  }
}

///|
/// Returns true if this file path is just a file name. i.e., Its parent is
/// the empty string.
fn is_file_name(path : String) -> Bool {
  !path.contains("/")
}

///|
/// The final component of the path, if it is a normal file.
///
/// If the path terminates in `.`, `..`, or consists solely of a root of
/// prefix, this will return `None`.
fn file_name(path : String) -> String? {
  let n = path.length()
  if n == 0 {
    return None
  } else if n == 1 && path[0] == '.' {
    return None
  } else if path[n - 1] == '.' {
    return None
  } else if n >= 2 && path.has_suffix("..") {
    return None
  }
  let last_slash = match path.rev_find("/") {
    Some(i) => i + 1
    None => 0
  }
  Some(path.unsafe_substring(start=last_slash, end=n))
}
