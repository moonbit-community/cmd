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
/// GNU rm rejects final . and .. components, and preserves the filesystem root
/// by default. An explicitly named working directory is not an extra policy.
fn protects_removal_operand(
  path : String,
  preserve_root~ : Bool = true,
) -> Bool {
  let normalized = if @platform.is_windows() {
    path.replace_all(old="\\", new="/")
  } else {
    path
  }
  let mut end = normalized.length()
  while end > 0 && normalized[end - 1] == '/' {
    end -= 1
  }
  let pieces = normalized[:end].split("/").collect()
  let final_component = pieces.last().unwrap_or("")
  final_component == "." ||
  final_component == ".." ||
  (preserve_root && is_filesystem_root(path))
}
