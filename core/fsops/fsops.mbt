///|
pub(all) suberror FsOpError {
  FsOpError(String)
}

///|
/// The creation modes needed by command-specific overwrite policies. The
/// caller owns the policy decision; this helper only maps it to the portable
/// MoonBit filesystem primitive.
#derive(Eq, Debug)
pub(all) enum OutputMode {
  CreateNew
  CreateOrTruncate
  AppendOrCreate
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
pub async fn open_output(
  path : String,
  output_mode : OutputMode,
  permission~ : Int32 = 0o644,
) -> @fs.File {
  let path = @platform.normalize_input_separators(path)
  match output_mode {
    CreateNew =>
      @fs.open(path, mode=WriteOnly, create_mode=CreateNew, permission~)
    CreateOrTruncate =>
      @fs.open(path, mode=WriteOnly, create_mode=CreateOrTruncate, permission~)
    AppendOrCreate =>
      @fs.open(
        path,
        mode=WriteOnly,
        append=true,
        create_mode=OpenOrCreate,
        permission~,
      )
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

///|
pub extend OutputMode with Eq::{not_equal, equal}

///|
pub extend OutputMode with @debug.Debug::{to_repr}
