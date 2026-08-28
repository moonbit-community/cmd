///|
pub(all) suberror FsOpError {
  FsOpError(String)
}

///|
pub fn basename(value : String) -> String {
  @path.Path(@platform.normalize_input_separators(value)).basename().to_owned()
}

///|
pub fn dirname(value : String) -> String {
  @path.Path(@platform.normalize_input_separators(value)).dirname().to_string()
}

///|
pub fn join(parent : String, child : String) -> String {
  @path.Path(@platform.normalize_input_separators(parent))
  .join(Path(@platform.normalize_input_separators(child)))
  .to_string()
}

///|
fn comparable(path : String) -> String {
  if @platform.is_windows() {
    path.to_lower()
  } else {
    path
  }
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
pub fn protects_working_directory(path : String) -> Bool {
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

///|
pub async fn kind_if_exists(path : String) -> @fs.FileKind? {
  let path = @platform.normalize_input_separators(path)
  try @fs.kind(path, follow_symlink=false) catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => None
    err => raise err
  } noraise {
    kind => Some(kind)
  }
}

///|
async fn copy_regular_file(
  source : String,
  destination : String,
  replace : Bool,
) -> Bool {
  match kind_if_exists(destination) {
    Some(Directory) =>
      raise FsOpError("destination is a directory: '\{destination}'")
    Some(SymLink) =>
      raise FsOpError("refusing to overwrite symbolic link: '\{destination}'")
    Some(Regular) => {
      if !replace {
        return false
      }
      if @fs.realpath(source) == @fs.realpath(destination) {
        raise FsOpError("source and destination are the same file")
      }
    }
    Some(_) => raise FsOpError("unsupported destination type: '\{destination}'")
    None => ()
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let output = @fs.open(
    destination,
    mode=WriteOnly,
    create_mode=CreateOrTruncate,
  )
  defer output.close()
  output.write_reader(input)
  true
}

///|
async fn copy_entry(
  source : String,
  destination : String,
  replace : Bool,
) -> Bool {
  match @fs.kind(source, follow_symlink=false) {
    Regular => copy_regular_file(source, destination, replace)
    Directory => {
      match kind_if_exists(destination) {
        Some(Directory) => ()
        Some(_) =>
          raise FsOpError("destination is not a directory: '\{destination}'")
        None => @fs.mkdir(destination)
      }
      let entries = @fs.readdir(
        source,
        include_hidden=true,
        include_special=false,
        sort=false,
      )
      entries.sort_by((left, right) => left.lexical_compare(right))
      let mut copied = false
      for entry in entries {
        if copy_entry(join(source, entry), join(destination, entry), replace) {
          copied = true
        }
      }
      copied || entries.is_empty()
    }
    SymLink =>
      raise FsOpError("symbolic-link sources are not supported: '\{source}'")
    _ => raise FsOpError("unsupported source type: '\{source}'")
  }
}

///|
async fn canonical_new_path(path : String) -> String {
  let parent = dirname(path)
  join(@fs.realpath(parent), basename(path))
}

///|
pub async fn ensure_not_nested_destination(
  source : String,
  destination : String,
) -> Unit {
  let source = @platform.normalize_input_separators(source)
  let destination = @platform.normalize_input_separators(destination)
  let source_real = @fs.realpath(source)
  let destination_real = match kind_if_exists(destination) {
    Some(SymLink) =>
      raise FsOpError(
        "refusing to use symbolic-link destination: '\{destination}'",
      )
    Some(_) => @fs.realpath(destination)
    None => canonical_new_path(destination)
  }
  if is_same_or_descendant(destination_real, source_real) {
    raise FsOpError("directory destination is inside the source")
  }
}

///|
pub async fn copy_path(
  source : String,
  destination : String,
  recursive : Bool,
  replace : Bool,
) -> Bool {
  let source = @platform.normalize_input_separators(source)
  let destination = @platform.normalize_input_separators(destination)
  let source_kind = @fs.kind(source, follow_symlink=false)
  if source_kind == Directory && !recursive {
    raise FsOpError("omitting directory: '\{source}'")
  }
  if source_kind == SymLink {
    raise FsOpError("symbolic-link sources are not supported: '\{source}'")
  }
  if source_kind == Directory {
    ensure_not_nested_destination(source, destination)
  }
  copy_entry(source, destination, replace)
}

///|
pub async fn remove_path(path : String, recursive : Bool) -> Unit {
  let path = @platform.normalize_input_separators(path)
  match @fs.kind(path, follow_symlink=false) {
    Directory => {
      if !recursive {
        raise FsOpError("cannot remove directory without recursion: '\{path}'")
      }
      let entries = @fs.readdir(
        path,
        include_hidden=true,
        include_special=false,
        sort=false,
      )
      for entry in entries {
        remove_path(join(path, entry), true)
      }
      @fs.rmdir(path)
    }
    _ => @fs.remove(path)
  }
}
