///|
pub fn expand_text(
  value : String,
  root : String,
  http_base? : String,
) -> String {
  let expanded = value.replace_all(old="${WORK}", new=root)
  match http_base {
    Some(base) => expanded.replace_all(old="${HTTP_BASE}", new=base)
    None => expanded
  }
}

///|
pub fn expand_args(
  args : ArrayView[String],
  root : String,
  http_base? : String,
) -> Array[String] {
  args.map(arg => expand_text(arg, root, http_base?))
}

///|
pub fn expand_fixture_content(content : Bytes, http_base? : String) -> Bytes {
  guard http_base is Some(base) else { return content }
  let text = @utf8.decode(content) catch { _ => return content }
  @utf8.encode(text.replace_all(old="${HTTP_BASE}", new=base))
}

///|
pub async fn prepare_fixture(
  root : String,
  fixture : Case,
  http_base? : String,
) -> Unit {
  for file in fixture.files {
    guard safe_relative_path(file.path) else {
      fail("unsafe fixture path: \{file.path}")
    }
    let destination = @path.Path(root).join(Path(file.path)).to_string()
    let parent = @path.Path(destination).dirname().to_string()
    if !@fs.exists(parent) {
      @fs.mkdir(parent, recursive=true)
    }
    match file.kind {
      Some("symlink") => {
        guard file.target is Some(target) && safe_symlink_target(target) else {
          fail("unsafe symlink target")
        }
        @fs.symlink(target~, destination)
      }
      Some("directory") =>
        @fs.mkdir(destination, recursive=true, permission?=file.mode)
      Some("hardlink") => {
        guard file.target is Some(target) && safe_relative_path(target) else {
          fail("unsafe hardlink target")
        }
        guard !(@async.platform is Windows) else {
          fail("hardlink fixture observation unavailable on Windows")
        }
        let link = run("ln", [
          @path.Path(root).join(Path(target)).to_string(),
          destination,
        ])
        guard link.status == 0 else { fail("host hardlink fixture failed") }
      }
      _ =>
        @fs.write_file(
          destination,
          expand_fixture_content(
            input_bytes(
              file.content_hex,
              file.content_text.map(value => {
                expand_text(value, root, http_base?)
              }),
              file.path,
            ),
            http_base?,
          ),
          permission?=file.mode,
        )
    }
    for (flag, time) in [("-a", file.atime), ("-m", file.mtime)] {
      if time is Some(time) {
        guard !(@async.platform is Windows) else {
          fail("fixed timestamp fixture requires POSIX observer")
        }
        let set = run("touch", [flag, "-t", time, destination])
        guard set.status == 0 else { fail("fixed timestamp fixture failed") }
      }
    }
    if fixture.delay_ms is Some(delay) && delay > 0 {
      @async.sleep(delay)
    }
  }
}

///|
pub fn is_network_case(fixture : Case) -> Bool {
  fixture.args.any(arg => {
    arg.contains("${HTTP_BASE}") || arg.contains("${HTTPS_BASE}")
  }) ||
  fixture.files.any(file => {
    file.content_text.unwrap_or("").contains("${HTTP_BASE}") ||
    file.content_hex
    .unwrap_or("")
    .to_lower()
    .contains("247b485454505f424153457d")
  })
}

///|
fn kind_name(kind : @fs.FileKind) -> String {
  match kind {
    Regular => "file"
    Directory => "directory"
    SymLink => "symlink"
    BlockDevice => "block-device"
    CharDevice => "character-device"
    Pipe => "pipe"
    Socket => "socket"
    Unknown => "unknown"
  }
}

///|
pub(all) struct SnapshotEntry {
  path : String
  kind : String
  content : Bytes
  metadata : Map[String, String]
} derive(Debug)

///|
async fn snapshot_into(
  root : String,
  relative : String,
  entries : Array[SnapshotEntry],
  observe : ArrayView[String],
) -> Unit {
  let directory = if relative == "" {
    root
  } else {
    @path.Path(root).join(Path(relative)).to_string()
  }
  let names = @fs.readdir(
    directory,
    include_hidden=true,
    include_special=false,
    sort=true,
  )
  for name in names {
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child = @path.Path(root).join(Path(child_relative)).to_string()
    let kind = @fs.kind(child, follow_symlink=false)
    // Collect metadata before content: reading a file can update its atime.
    let metadata : Map[String, String] = Map([])
    for dimension in observe {
      match dimension {
        "mode" | "identity" => {
          guard !(@async.platform is Windows) else {
            fail("required observation unavailable: \{dimension}")
          }
          let format = if @async.platform is MacOS {
            if dimension == "mode" {
              "%Lp"
            } else {
              "%d:%i"
            }
          } else if dimension == "mode" {
            "%a"
          } else {
            "%d:%i"
          }
          let flag = if @async.platform is MacOS { "-f" } else { "-c" }
          let result = run("stat", [flag, format, child])
          guard result.status == 0 else {
            fail("host stat failed: \{dimension}")
          }
          metadata[dimension] = @utf8.decode(result.stdout).trim().to_owned()
        }
        "symlink-target" =>
          if kind == SymLink {
            let result = run("readlink", [child])
            guard result.status == 0 else { fail("host readlink failed") }
            let target = @utf8.decode(result.stdout)
            metadata[dimension] = if target.has_suffix("\n") {
              target[:target.length() - 1].to_owned()
            } else {
              target
            }
          }
        "atime" => {
          let (s, n) = @fs.atime(child, follow_symlink=false)
          metadata[dimension] = "\{s}:\{n}"
        }
        "mtime" => {
          let (s, n) = @fs.mtime(child, follow_symlink=false)
          metadata[dimension] = "\{s}:\{n}"
        }
        "ctime" => {
          let (s, n) = @fs.ctime(child, follow_symlink=false)
          metadata[dimension] = "\{s}:\{n}"
        }
        "content" | "type" => ()
        _ => fail("unknown observation dimension: \{dimension}")
      }
    }
    let content = if kind == Regular {
      @fs.read_file(child).binary()
    } else {
      b""
    }
    entries.push({
      path: child_relative,
      kind: kind_name(kind),
      content,
      metadata,
    })
    if kind == Directory {
      snapshot_into(root, child_relative, entries, observe)
    }
  }
}

///|
pub async fn snapshot(
  root : String,
  observe? : ArrayView[String] = [],
  baseline? : Bool = false,
) -> Array[SnapshotEntry] {
  let entries : Array[SnapshotEntry] = []
  snapshot_into(root, "", entries, observe)
  // Baseline content inspection may itself access files. Anchor an unchanged
  // atime assertion after that inspection, before the candidate starts.
  if baseline && observe.contains("atime") {
    for entry in entries {
      let (s, n) = @fs.atime(
        @path.Path(root).join(Path(entry.path)).to_string(),
        follow_symlink=false,
      )
      entry.metadata["atime"] = "\{s}:\{n}"
    }
  }
  // Identity is meaningful only as a relation within one fixture.
  let representatives : Map[String, String] = Map([])
  for entry in entries {
    if entry.metadata.get("identity") is Some(identity) {
      let representative = representatives.get_or_default(identity, entry.path)
      representatives[identity] = representative
      entry.metadata["identity"] = representative
    }
  }
  entries
}

///|
pub fn snapshots_equal(
  left : ArrayView[SnapshotEntry],
  right : ArrayView[SnapshotEntry],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    let a = left[index]
    let b = right[index]
    if a.path != b.path ||
      a.kind != b.kind ||
      !bytes_equal(a.content, b.content) ||
      a.metadata != b.metadata {
      return false
    }
  }
  true
}

///|
pub fn normalize_text(
  data : Bytes,
  field : String,
  rules : ArrayView[Normalization],
  temporary_root : String,
) -> Bytes {
  if !rules.any(rule => rule.field == field) {
    return data
  }
  let mut text = @utf8.decode(data) catch { _ => return data }
  let normalize_separators = rules.any(rule => {
    rule.field == field && rule.rule == "path-separator"
  })
  let temporary_root = if normalize_separators {
    text = text.replace_all(old="\\", new="/")
    temporary_root.replace_all(old="\\", new="/")
  } else {
    temporary_root
  }
  for rule in rules {
    if rule.field == field {
      match rule.rule {
        "temporary-path" =>
          text = text.replace_all(old=temporary_root, new="<TMP>")
        "path-separator" => text = text.replace_all(old="\\", new="/")
        "working-directory" =>
          text = text
            .replace_all(old=temporary_root, new="<WORK>")
            .replace_all(old="/work", new="<WORK>")
        _ => ()
      }
    }
  }
  @utf8.encode(text)
}
