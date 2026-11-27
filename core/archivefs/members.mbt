///|
pub(all) suberror ArchiveError {
  ArchiveError(String)
}

///|
pub const MAX_BYTES : Int32 = 64 * 1024 * 1024

///|
pub const MAX_ENTRIES : Int32 = 65535

///|
pub(all) enum Content {
  Regular(BytesView)
  Directory
  Special
}

///|
pub(all) struct Member {
  name : String
  content : Content
}

///|
pub async fn read_bounded(reader : &@io.BinaryReader, limit : Int32) -> Bytes {
  let output = @buffer.Buffer()
  while reader.read() is Some(chunk) {
    guard chunk.length() <= limit - output.length() else {
      raise ArchiveError("archive size limit exceeded")
    }
    output.write_bytesview(chunk)
  }
  output.to_bytes()
}

///|
pub async fn read_archive(path : String) -> Bytes {
  if path == "-" {
    return read_bounded(@stdio.stdin, MAX_BYTES)
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  read_bounded(file, MAX_BYTES)
}

///|
pub async fn write_archive(path : String, bytes : BytesView) -> Unit {
  if path == "-" {
    @stdio.stdout.write(bytes)
  } else {
    @fs.write_binary(path, bytes, create_mode=CreateNew) catch {
      @os_error.OsError(AlreadyExists, ..) =>
        raise ArchiveError("archive already exists: " + path)
      error => raise error
    }
  }
}

///|
fn components(name : String) -> Array[String] raise ArchiveError {
  guard !name.is_empty() && !name.has_prefix("/") && !name.contains("\\") else {
    raise ArchiveError("invalid archive member: " + name)
  }
  let parts = []
  for part in name.split("/") {
    if part == "" || part == "." {
      continue
    }
    let stem = part.split(".").next().unwrap().trim_end().to_lower()
    let device = match stem {
      "aux" | "con" | "prn" | "nul" | "conin$" | "conout$" => true
      ['c', 'o', 'm', '0'..<='9' | '¹' | '²' | '³']
      | ['l', 'p', 't', '0'..<='9' | '¹' | '²' | '³'] => true
      _ => false
    }
    guard !device &&
      part != ".." &&
      !part.has_suffix(".") &&
      !part.has_suffix(" ") else {
      raise ArchiveError("invalid archive member: " + name)
    }
    for ch in part {
      guard ch >= ' ' && ch != '\u007f' && !":<>\"|?*".contains(ch.to_string()) else {
        raise ArchiveError("invalid archive member: " + name)
      }
    }
    parts.push(part.to_owned())
  }
  parts
}

///|
pub async fn collect(
  paths : ArrayView[String],
  recursive~ : Bool,
) -> Array[Member] {
  let members = []
  let mut remaining = MAX_BYTES
  let seen : Set[String] = Set([])
  let pending : Array[(String, Bool)] = []
  for path in paths {
    let parts = components(path)
    let mut name = ""
    for i, part in parts {
      name = if name == "" { part } else { name + "/" + part }
      if i + 1 != parts.length() &&
        !(@fs.kind(name, follow_symlink=false) is Directory) {
        raise ArchiveError("not a directory: " + name)
      }
    }
    pending.push(
      (
        if name == "" {
          "."
        } else {
          name
        },
        path.has_suffix("/") || path.has_suffix("/."),
      ),
    )
  }
  pending.rev_in_place()
  while pending.pop() is Some((name, require_directory)) {
    let kind = @fs.kind(name, follow_symlink=false)
    if require_directory && !(kind is Directory) {
      raise ArchiveError("not a directory: " + name)
    }
    if seen.contains(name) {
      continue
    }
    guard seen.length() < MAX_ENTRIES else {
      raise ArchiveError("too many archive members")
    }
    seen.insert(name)
    match kind {
      Regular => {
        let file = @fs.open(name, mode=ReadOnly)
        defer file.close()
        guard file.kind() is Regular else {
          raise ArchiveError("not a regular file: " + name)
        }
        let data = read_bounded(file, remaining)
        remaining -= data.length()
        members.push({ name, content: Regular(data[:]), })
      }
      Directory => {
        members.push({ name: name + "/", content: Directory, })
        if recursive {
          let children = @fs.readdir(name, include_hidden=true, sort=true)
          for i = children.length() - 1; i >= 0; i = i - 1 {
            let child = children[i]
            ignore(components(child))
            pending.push(
              (if name == "." { child } else { name + "/" + child }, false),
            )
          }
        }
      }
      _ => raise ArchiveError("unsupported archive member type: " + name)
    }
  }
  members
}

///|
async fn ensure_directory(path : String) -> Unit {
  @fs.mkdir(path) catch {
    @os_error.OsError(AlreadyExists, ..) => {
      guard @fs.kind(path, follow_symlink=false) is Directory else {
        raise ArchiveError("not a directory: " + path)
      }
    }
    error => raise error
  }
}

///|
priv enum Target {
  File
  Folder(Map[String, Target])
}

///|
pub async fn extract(
  members : ArrayView[Member],
  root : String,
  skip_existing~ : Bool = false,
  create_root~ : Bool = true,
) -> Unit {
  // Validate the complete selected namespace before creating any output.
  let targets = []
  let destinations : Map[String, Target] = Map([])
  for entry in members {
    let parts = components(entry.name)
    match entry.content {
      Special =>
        raise ArchiveError("unsupported archive member type: " + entry.name)
      Regular(_) if parts.is_empty() => raise ArchiveError("empty file name")
      _ => ()
    }
    let mut parent = destinations
    for i, part in parts {
      let key = part.to_lower()
      let file = i + 1 == parts.length() && entry.content is Regular(_)
      match parent.get(key) {
        Some(Folder(children)) if !file => parent = children
        Some(_) => raise ArchiveError("conflicting member: " + entry.name)
        None if file => parent[key] = File
        None => {
          let children = Map([])
          parent[key] = Folder(children)
          parent = children
        }
      }
    }
    targets.push(parts)
  }
  if create_root {
    ensure_directory(root)
  } else {
    guard @fs.kind(root, follow_symlink=false) is Directory else {
      raise ArchiveError("not a directory: " + root)
    }
  }
  for index, entry in members {
    let parts = targets[index]
    let mut path = root
    for
      component in parts[:if entry.content is Directory {
        parts.length()
      } else {
        parts.length() - 1
      }] {
      path = path + "/" + component
      ensure_directory(path)
    }
    if entry.content is Regular(data) {
      path = path + "/" + parts.last().unwrap()
      let file = @fs.open(path, mode=WriteOnly, create_mode=CreateNew) catch {
        @os_error.OsError(AlreadyExists, ..) if skip_existing => continue
        @os_error.OsError(AlreadyExists, ..) =>
          raise ArchiveError("destination already exists: " + path)
        error => raise error
      }
      defer file.close()
      file.write(data)
    }
  }
}
