///|
pub fn mode(text : String) -> Int32 raise {
  guard text.length() > 0 &&
    text.length() <= 4 &&
    text.iter().all(ch => ch >= '0' && ch <= '7') else {
    raise Failure("invalid mode: " + text)
  }
  @string.parse_int(text, radix=8)
}

///|
async fn make_directory(
  path : String,
  permission : Int32,
  apply_existing_mode~ : Bool,
) -> Unit {
  let parent = @fsops.dirname(path)
  if parent != path && parent != "." {
    make_directory(parent, 0o755, apply_existing_mode=false)
  }
  @fs.mkdir(path, permission~) catch {
    @os_error.OsError(AlreadyExists, ..) => {
      guard @fs.kind(path, follow_symlink=false) is Directory else {
        raise Failure("expected a directory: " + path)
      }
      if !apply_existing_mode {
        return
      }
    }
    error => raise error
  }
  @fs.chmod(path, permission)
}

///|
pub async fn directory(path : String, permission : Int32) -> Unit {
  make_directory(path, permission, apply_existing_mode=true)
}

///|
pub async fn file(
  source : String,
  dest : String,
  permission : Int32,
  leading~ : Bool,
) -> Unit {
  guard @fs.kind(source) is Regular else {
    raise Failure("expected a regular source file: " + source)
  }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  guard input.kind() is Regular else {
    raise Failure("expected a regular source file: " + source)
  }
  if leading {
    make_directory(@fsops.dirname(dest), 0o755, apply_existing_mode=false)
  }
  let out = @fs.open(
    dest,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=0o600,
  ) catch {
    @os_error.OsError(AlreadyExists, ..) =>
      raise Failure("destination already exists: " + dest)
    error => raise error
  }
  defer out.close()
  out.write_reader(input)
  @fs.chmod(dest, permission)
}

///|
pub async fn destination_is_directory(path : String) -> Bool {
  try @fs.kind(path) catch {
    @os_error.OsError(NotFound, ..) => false
    error => raise error
  } noraise {
    kind => kind is Directory
  }
}
