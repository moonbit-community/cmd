// Helpers that mirror the semantics of Rust's `std::path::Path` on Unix,
// operating on `String` paths with `/` separators.

///|
priv enum PathComp {
  Root
  CurDir
  ParentDir
  Normal(String)
} derive(Eq)

///|
/// Splits a path into components, like Rust's `Path::components`. Each
/// component is returned with its byte (UTF-16 code unit) span in `path`.
fn path_components(path : String) -> Array[(PathComp, Int32, Int32)] {
  let out = []
  let n = path.length()
  let mut i = 0
  if n > 0 && path[0] == '/' {
    out.push((Root, 0, 1))
    while i < n && path[i] == '/' {
      i += 1
    }
  }
  let mut first = out.is_empty()
  while i < n {
    let start = i
    while i < n && path[i] != '/' {
      i += 1
    }
    let comp = path.unsafe_substring(start~, end=i)
    if comp == "." {
      // A `.` is only a component at the very beginning of a relative path.
      if first {
        out.push((CurDir, start, i))
      }
    } else if comp == ".." {
      out.push((ParentDir, start, i))
    } else if comp != "" {
      out.push((Normal(comp), start, i))
    }
    first = false
    while i < n && path[i] == '/' {
      i += 1
    }
  }
  out
}

///|
/// Like Rust's `Path::parent`.
fn path_parent(path : String) -> String? {
  let comps = path_components(path)
  guard comps.last() is Some((last, _, _)) else { return None }
  if last is Root {
    return None
  }
  if comps.length() == 1 {
    return Some("")
  }
  let (_, _, end) = comps[comps.length() - 2]
  Some(path.unsafe_substring(start=0, end~))
}

///|
/// Like Rust's `Path::file_name`.
fn path_file_name(path : String) -> String? {
  match path_components(path).last() {
    Some((Normal(name), _, _)) => Some(name)
    _ => None
  }
}

///|
/// Like Rust's `Path::join` (`PathBuf::push`) on Unix.
fn path_join(base : String, child : String) -> String {
  if child.has_prefix("/") {
    return child
  }
  if base == "" || base.has_suffix("/") {
    base + child
  } else {
    base + "/" + child
  }
}

///|
/// Like Rust's `Path::strip_prefix` (component-wise). (Only used by tests.)
#warnings("-unused_value")
fn path_strip_prefix(path : String, base : String) -> String? {
  let pc = path_components(path)
  let bc = path_components(base)
  if bc.length() > pc.length() {
    return None
  }
  for i, b in bc {
    if pc[i].0 != b.0 {
      return None
    }
  }
  if pc.length() == bc.length() {
    Some("")
  } else {
    let (_, start, _) = pc[bc.length()]
    Some(path.unsafe_substring(start~, end=path.length()))
  }
}

///|
/// Like Rust's `Path::has_root` on Unix.
fn path_has_root(path : String) -> Bool {
  path.has_prefix("/")
}

///|
/// Resolve paths through the released public filesystem API.
async fn canonicalize(path : String) -> String {
  @sys.canonicalize(path)
}

///|
/// Compares two strings by their UTF-8 encoding, byte-wise (like Rust's
/// `OsStr`/`str` ordering).
pub fn compare_utf8(a : String, b : String) -> Int32 {
  // Comparing by Unicode scalar values is equivalent to comparing the UTF-8
  // encodings byte-wise.
  let ai = a.iter()
  let bi = b.iter()
  for ;; {
    match (ai.next(), bi.next()) {
      (None, None) => return 0
      (None, Some(_)) => return -1
      (Some(_), None) => return 1
      (Some(x), Some(y)) => if x != y { return if x < y { -1 } else { 1 } }
    }
  }
}
