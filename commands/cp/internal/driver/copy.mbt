///|
#derive(Eq)
priv enum LinkTraversal {
  NeverFollowLinks
  FollowCommandLineLinks
  FollowAllLinks
}

///|
async fn copy_regular_file(
  source : String,
  destination : String,
  replace : Bool,
) -> Bool {
  match @fsops.kind_if_exists(destination) {
    Some(Directory) =>
      raise @fsops.FsOpError("destination is a directory: '\{destination}'")
    Some(SymLink) =>
      raise @fsops.FsOpError(
        "refusing to overwrite symbolic link: '\{destination}'",
      )
    Some(Regular) => {
      if !replace {
        return false
      }
      raise @fsops.FsOpError(
        "overwriting an existing file requires public file identity and handle truncation APIs",
      )
    }
    Some(_) =>
      raise @fsops.FsOpError("unsupported destination type: '\{destination}'")
    None => ()
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let output = @fs.open(
    destination,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=0o666,
  )
  defer output.close()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  while input.read(buffer, max_len=buffer.length()) is count && count > 0 {
    output.write(bytes[:count])
  }
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
    raise @fsops.FsOpError(
      "symbolic-link sources are not supported: '\{source}'",
    )
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
      match @fsops.kind_if_exists(destination) {
        Some(Directory) =>
          raise @fsops.FsOpError("destination is a directory: '\{destination}'")
        Some(SymLink) =>
          raise @fsops.FsOpError(
            "refusing to overwrite symbolic link: '\{destination}'",
          )
        Some(Regular) =>
          raise @fsops.FsOpError(
            "overwriting an existing file requires public file identity and handle truncation APIs",
          )
        Some(_) =>
          raise @fsops.FsOpError(
            "unsupported destination type: '\{destination}'",
          )
        None => ()
      }
    Directory => {
      let real = @fs.realpath(source)
      if ancestors.contains(real) {
        raise @fsops.FsOpError("symbolic-link directory cycle at '\{source}'")
      }
      match @fsops.kind_if_exists(destination) {
        Some(Directory) | None => ()
        Some(_) =>
          raise @fsops.FsOpError(
            "destination is not a directory: '\{destination}'",
          )
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
          @fsops.join(source, entry),
          @fsops.join(destination, entry),
          traversal,
          false,
          next_ancestors,
        )
      }
    }
    SymLink =>
      raise @fsops.FsOpError(
        "symbolic-link sources are not supported: '\{source}'",
      )
    _ => raise @fsops.FsOpError("unsupported source type: '\{source}'")
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
      let created = match @fsops.kind_if_exists(destination) {
        Some(Directory) => false
        Some(_) =>
          raise @fsops.FsOpError(
            "destination is not a directory: '\{destination}'",
          )
        None => {
          @fs.mkdir(destination, permission=0o777)
          true
        }
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
            @fsops.join(source, entry),
            @fsops.join(destination, entry),
            replace,
            traversal,
            false,
          ) {
          copied = true
        }
      }
      copied || created
    }
    SymLink =>
      raise @fsops.FsOpError(
        "symbolic-link sources are not supported: '\{source}'",
      )
    _ => raise @fsops.FsOpError("unsupported source type: '\{source}'")
  }
}

///|
async fn copy_path_with_links(
  source : String,
  destination : String,
  recursive : Bool,
  replace : Bool,
  traversal : LinkTraversal,
  preserve_permissions~ : Bool = true,
) -> Bool {
  preflight_copy_path(
    source,
    destination,
    recursive,
    traversal,
    preserve_permissions~,
  )
  copy_entry(
    @platform.normalize_input_separators(source),
    @platform.normalize_input_separators(destination),
    replace,
    traversal,
    true,
  )
}

///|
async fn preflight_copy_path(
  source : String,
  destination : String,
  recursive : Bool,
  traversal : LinkTraversal,
  preserve_permissions~ : Bool = true,
) -> Unit {
  let source = @platform.normalize_input_separators(source)
  let destination = @platform.normalize_input_separators(destination)
  let source_kind = copy_source_kind(source, traversal, true)
  if source_kind == Directory && !recursive {
    raise @fsops.FsOpError("omitting directory: '\{source}'")
  }
  if source_kind == Directory {
    @fsops.ensure_not_nested_destination(source, destination)
  }
  if preserve_permissions && !@platform.permission_reads_supported() {
    raise @fsops.FsOpError(
      "preserving source permissions requires a public mode reader; use --no-preserve=mode for a new destination",
    )
  }
  preflight_copy_entry(source, destination, traversal, true, [])
}
