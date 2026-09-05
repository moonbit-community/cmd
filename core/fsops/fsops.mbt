///|
pub(all) suberror FsOpError {
  FsOpError(String)
}

///|
/// The creation modes needed by command-specific overwrite policies. The
/// caller owns the policy decision; this helper only maps it to the portable
/// MoonBit filesystem primitive.
pub(all) enum OutputMode {
  CreateNew
  CreateOrTruncate
  AppendOrCreate
} derive(Eq, Debug)

///|
pub(all) enum LinkTraversal {
  NeverFollowLinks
  FollowCommandLineLinks
  FollowAllLinks
} derive(Eq, Debug)

///|
pub(all) struct FileMetadata {
  kind : @fs.FileKind
  size : Int64?
  mtime_seconds : Int64
  mtime_nanoseconds : Int
} derive(Eq, Debug)

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
pub async fn metadata_if_exists(
  path : String,
  follow_symlink? : Bool = false,
) -> FileMetadata? {
  let path = @platform.normalize_input_separators(path)
  let kind = @fs.kind(path, follow_symlink~) catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => return None
    err => raise err
  }
  let size = if kind == Regular {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    Some(file.size())
  } else {
    None
  }
  let (mtime_seconds, mtime_nanoseconds) = @fs.mtime(path, follow_symlink~)
  Some({ kind, size, mtime_seconds, mtime_nanoseconds, })
}

///|
pub async fn open_output(
  path : String,
  output_mode : OutputMode,
  permission? : Int = 0o644,
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
/// Atomically create the first unoccupied numbered sibling and return its path
/// and open handle. The original path is attempted first, followed by `.1`,
/// `.2`, and so on. Commands retain ownership of whether this naming rule is
/// appropriate for their upstream.
pub async fn open_unique_numbered_output(
  path : String,
  permission? : Int = 0o644,
) -> (String, @fs.File) {
  let path = @platform.normalize_input_separators(path)
  for suffix = 0; ; suffix = suffix + 1 {
    let candidate = if suffix == 0 {
      path
    } else {
      path + "." + suffix.to_string()
    }
    let file = @fs.open(
      candidate,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission~,
    ) catch {
      @os_error.OSError(_) as err if err.is_EEXIST() => continue
      err => raise err
    }
    return (candidate, file)
  }
}

///|
pub async fn cleanup_file_if_exists(path : String) -> Unit {
  try @fs.kind(path, follow_symlink=false) catch {
    @os_error.OSError(_) as err if err.is_ENOENT() => return
    err => raise err
  } noraise {
    Directory => raise FsOpError("temporary path is a directory: '\{path}'")
    _ => @fs.remove(path)
  }
}

///|
/// Commit a fully-written temporary file with a single rename. If the commit
/// fails, the temporary path is removed before the original error is raised.
pub async fn commit_temporary_file(
  temporary : String,
  destination : String,
  replace? : Bool = true,
) -> Unit {
  errdefer (cleanup_file_if_exists(temporary) catch { _ => () })
  @fs.rename(temporary, destination, replace~)
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
async fn copy_source_kind(
  source : String,
  traversal : LinkTraversal,
  command_line : Bool,
) -> @fs.FileKind {
  let kind = @fs.kind(source, follow_symlink=false)
  if kind != SymLink {
    return kind
  }
  if traversal == FollowAllLinks ||
    (traversal == FollowCommandLineLinks && command_line) {
    @fs.kind(source, follow_symlink=true)
  } else {
    raise FsOpError("symbolic-link sources are not supported: '\{source}'")
  }
}

///|
async fn preflight_copy_entry(
  source : String,
  destination : String,
  traversal : LinkTraversal,
  command_line : Bool,
  ancestors : Array[String],
) -> Unit {
  let kind = copy_source_kind(source, traversal, command_line)
  match kind {
    Regular =>
      match kind_if_exists(destination) {
        Some(Directory) =>
          raise FsOpError("destination is a directory: '\{destination}'")
        Some(SymLink) =>
          raise FsOpError(
            "refusing to overwrite symbolic link: '\{destination}'",
          )
        Some(Regular) =>
          if @fs.realpath(source) == @fs.realpath(destination) {
            raise FsOpError("source and destination are the same file")
          }
        Some(_) =>
          raise FsOpError("unsupported destination type: '\{destination}'")
        None => ()
      }
    Directory => {
      let real = @fs.realpath(source)
      if ancestors.contains(real) {
        raise FsOpError("symbolic-link directory cycle at '\{source}'")
      }
      match kind_if_exists(destination) {
        Some(Directory) | None => ()
        Some(_) =>
          raise FsOpError("destination is not a directory: '\{destination}'")
      }
      let next_ancestors = ancestors.copy()
      next_ancestors.push(real)
      let entries = @fs.readdir(
        source,
        include_hidden=true,
        include_special=false,
        sort=false,
      )
      entries.sort_by((left, right) => left.lexical_compare(right))
      for entry in entries {
        preflight_copy_entry(
          join(source, entry),
          join(destination, entry),
          traversal,
          false,
          next_ancestors,
        )
      }
    }
    SymLink =>
      raise FsOpError("symbolic-link sources are not supported: '\{source}'")
    _ => raise FsOpError("unsupported source type: '\{source}'")
  }
}

///|
async fn copy_entry(
  source : String,
  destination : String,
  replace : Bool,
  traversal : LinkTraversal,
  command_line : Bool,
) -> Bool {
  match copy_source_kind(source, traversal, command_line) {
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
        if copy_entry(
            join(source, entry),
            join(destination, entry),
            replace,
            traversal,
            false,
          ) {
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
  copy_path_with_links(
    source,
    destination,
    recursive,
    replace,
    NeverFollowLinks,
  )
}

///|
pub async fn copy_path_with_links(
  source : String,
  destination : String,
  recursive : Bool,
  replace : Bool,
  traversal : LinkTraversal,
) -> Bool {
  preflight_copy_path(source, destination, recursive, traversal)
  copy_entry(
    @platform.normalize_input_separators(source),
    @platform.normalize_input_separators(destination),
    replace,
    traversal,
    true,
  )
}

///|
pub async fn preflight_copy_path(
  source : String,
  destination : String,
  recursive : Bool,
  traversal : LinkTraversal,
) -> Unit {
  let source = @platform.normalize_input_separators(source)
  let destination = @platform.normalize_input_separators(destination)
  let source_kind = copy_source_kind(source, traversal, true)
  if source_kind == Directory && !recursive {
    raise FsOpError("omitting directory: '\{source}'")
  }
  if source_kind == Directory {
    ensure_not_nested_destination(source, destination)
  }
  preflight_copy_entry(source, destination, traversal, true, [])
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
