///|
fn comparable(path : String) -> String {
  if @platform.is_windows() {
    path.to_lower()
  } else {
    path
  }
}

///|
fn canonical_path(path : String) -> String {
  let separator = @path.sep.to_string()
  let mut normalized = @path.Path(@platform.normalize_input_separators(path))
    .normalize()
    .to_string()
  while normalized.has_suffix(separator) {
    let parent = @path.Path(normalized).dirname().to_string()
    if comparable(parent) == comparable(normalized) {
      break
    }
    normalized = normalized[:normalized.length() - separator.length()].to_owned()
  }
  normalized
}

///|
fn is_filesystem_root(path : String) -> Bool {
  let normalized = canonical_path(path)
  let value = @path.Path(normalized)
  value.is_absolute() &&
  comparable(canonical_path(value.dirname().to_string())) ==
  comparable(normalized)
}

///|
fn is_same_or_descendant(path : String, root : String) -> Bool {
  let normalized_path = canonical_path(path)
  let normalized_root = canonical_path(root)
  if comparable(normalized_path) == comparable(normalized_root) {
    return true
  }
  let prefix = if normalized_root.has_suffix(@path.sep.to_string()) {
    normalized_root
  } else {
    normalized_root + @path.sep.to_string()
  }
  comparable(normalized_path).has_prefix(comparable(prefix))
}

///|
fn protects_working_directory(path : String) -> Bool {
  if is_filesystem_root(path) {
    return true
  }
  guard @env.current_dir() is Some(current) else {
    let normalized = canonical_path(path)
    return normalized == "." ||
      normalized == ".." ||
      normalized.has_prefix("../")
  }
  let current = canonical_path(current)
  let target = @path.Path(path)
  let target = if target.is_absolute() {
    canonical_path(target.to_string())
  } else {
    canonical_path(@path.Path(current).join(target).to_string())
  }
  comparable(target) == comparable(current) ||
  is_same_or_descendant(current, target)
}
