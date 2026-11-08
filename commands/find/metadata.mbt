///|
priv enum FindMetadata[T] {
  Unloaded
  Available(T)
  Unavailable(@os_error.OSError)
}

///|
async fn find_lookup_path(path : String) -> String {
  if !(@async.platform is Windows) && path.has_suffix("/") {
    if @fs.kind(path) != Directory {
      raise @os_error.OSError(@os_error.errno_ENOTDIR, context=path)
    }
    @fs.realpath(path)
  } else {
    path
  }
}

///|
fn is_link_loop(error : @os_error.OSError) -> Bool {
  let @os_error.OSError(code, ..) = error
  match @async.platform {
    Linux => code == 40
    MacOS => code == 62
    Windows => code == 1921
  }
}

///|
fn find_os_message(error : @os_error.OSError) -> String {
  if error.is_ENOENT() {
    "No such file or directory"
  } else if error.is_ENOTDIR() {
    "Not a directory"
  } else if error.is_EACCES() {
    "Permission denied"
  } else if is_link_loop(error) {
    "Too many levels of symbolic links"
  } else {
    error.to_string()
  }
}

///|
async fn FindEntry::metadata_error(
  self : FindEntry,
  error : @os_error.OSError,
  dimension : String,
) -> Unit {
  self.failed = true
  let @os_error.OSError(code, ..) = error
  let message = if code == @os_error.errno_ENOTSUP {
    "unsupported capability: " + dimension + " metadata"
  } else {
    find_os_message(error)
  }
  @stdio.stderr.write("find: '\{self.path}': \{message}\n")
}

///|
async fn FindEntry::load_size(self : FindEntry) -> Unit {
  if self.size is Unloaded {
    self.size = try {
      let size = @fs.file_size(find_lookup_path(self.path))
      if size < 0L {
        raise FindError("negative entry size: '\{self.path}'")
      }
      Available(size)
    } catch {
      @os_error.OSError(_) as error => Unavailable(error)
      error => raise error
    }
  }
}

///|
async fn FindEntry::byte_size(self : FindEntry) -> Int64? {
  self.load_size()
  match self.size {
    Available(value) => Some(value)
    Unavailable(error) => {
      self.metadata_error(error, "entry size")
      None
    }
    Unloaded => abort("size load did not finish")
  }
}

///|
async fn FindEntry::load_timestamp(
  self : FindEntry,
  kind : @fsops.TimestampKind,
) -> FindMetadata[@fsops.FileTimestamp] {
  let previous = match kind {
    AccessTime => self.atime
    ModificationTime => self.mtime
    StatusChangeTime => self.ctime
  }
  if !(previous is Unloaded) {
    return previous
  }
  let value = Available(
    @fsops.read_file_timestamp(
      find_lookup_path(self.path),
      kind,
      follow_symlink=false,
    ),
  ) catch {
    @os_error.OSError(_) as error => Unavailable(error)
    error => raise error
  }
  match kind {
    AccessTime => self.atime = value
    ModificationTime => self.mtime = value
    StatusChangeTime => self.ctime = value
  }
  value
}

///|
async fn FindEntry::timestamp(
  self : FindEntry,
  kind : @fsops.TimestampKind,
) -> @fsops.FileTimestamp? {
  match self.load_timestamp(kind) {
    Available(value) => Some(value)
    Unavailable(error) => {
      self.metadata_error(error, "timestamp")
      None
    }
    Unloaded => abort("timestamp load did not finish")
  }
}

///|
// GNU stat fields precede directory reads and survive descendant processing
// and deletion. Collect only fields named by the expression, and report a
// capability failure only when its predicate is evaluated. Access and names
// remain separate live observations.
async fn FindEntry::load_stat_fields(
  self : FindEntry,
  needs : MetadataNeeds,
) -> Unit {
  if needs.size || (needs.regular_size && self.kind == Regular) {
    self.load_size()
  }
  if needs.atime {
    ignore(self.load_timestamp(AccessTime))
  }
  if needs.mtime {
    ignore(self.load_timestamp(ModificationTime))
  }
  if needs.ctime {
    ignore(self.load_timestamp(StatusChangeTime))
  }
}

///|
async fn find_access(path : String, mode : Char) -> Bool {
  try {
    match mode {
      'r' => @fs.can_read(path)
      'w' => @fs.can_write(path)
      _ => @fs.can_execute(path)
    }
  } catch {
    @os_error.OSError(_) => false
    error => raise error
  }
}

///|
async fn FindEntry::followed_kind_matches(
  self : FindEntry,
  wanted : Char,
) -> Bool {
  if self.kind != SymLink {
    return kind_matches(self.kind, wanted)
  }
  kind_matches(@fs.kind(self.path), wanted) catch {
    // GNU optionl_stat first falls back to lstat for ENOENT/ENOTDIR;
    // pred_xtype additionally falls back for ELOOP.
    @os_error.OSError(_) as error if error.is_ENOENT() ||
      error.is_ENOTDIR() ||
      is_link_loop(error) => kind_matches(SymLink, wanted)
    @os_error.OSError(_) as error => {
      self.metadata_error(error, "target type")
      false
    }
    error => raise error
  }
}
