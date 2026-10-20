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
pub fn expand_environment(
  values : Map[String, String],
  root : String,
  http_base? : String,
) -> Map[String, String] {
  let expanded : Map[String, String] = Map([])
  for name, value in values {
    expanded[name] = expand_text(value, root, http_base?)
  }
  expanded
}

///|
pub fn expand_fixture_content(content : Bytes, http_base? : String) -> Bytes {
  guard http_base is Some(base) else { return content }
  let text = @utf8.decode(content) catch { _ => return content }
  @utf8.encode(text.replace_all(old="${HTTP_BASE}", new=base))
}

///|
fn windows_link_observation(
  data : Bytes,
  root : String,
) -> (String, String) raise {
  let value = @json.parse(@utf8.decode(data))
  guard value is { "kind": String(kind), "target": String(target), .. } &&
    (kind == "SymbolicLink" || kind == "Junction") &&
    target != "" else {
    fail("Windows link observer did not return a link type and target")
  }
  let target = target.replace_all(old="\\", new="/")
  let target = if target.has_prefix("//?/") {
    target[4:].to_owned()
  } else {
    target
  }
  let root = root.replace_all(old="\\", new="/")
  let prefix = root + "/"
  let target = if target.to_lower().has_prefix(prefix.to_lower()) {
    "${WORK}/" + target[prefix.length():].to_owned()
  } else {
    target
  }
  (kind, target)
}

///|
async fn observe_windows_link(path : String, root : String) -> (String, String) {
  // A fixed host observer collects properties unavailable through public fs.
  // The path is data in the child environment, never PowerShell source.
  let result = run(
    "powershell.exe",
    [
      "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $item = Get-Item -LiteralPath $env:MOONCMD_OBSERVED_LINK -Force; [pscustomobject]@{kind=$item.LinkType; target=@($item.Target)[0]} | ConvertTo-Json -Compress",
    ],
    extra_env=Map([("MOONCMD_OBSERVED_LINK", path)]),
  ) catch {
    error => fail("required Windows link observer unavailable: \{error}")
  }
  guard result.status == 0 else {
    fail(
      "required Windows link observer failed: " + @utf8.decode(result.stderr),
    )
  }
  windows_link_observation(result.stdout, root)
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
      Some("symbolic-link") | Some("junction") => {
        guard file.target is Some(target) && safe_symlink_target(target) else {
          fail("unsafe link target")
        }
        let junction = file.kind == Some("junction")
        if junction {
          guard @async.platform is Windows else {
            fail("junction fixture requires Windows")
          }
          let target_path = @path.Path(parent).join(Path(target)).to_string()
          guard @fs.kind(target_path, follow_symlink=false) == Directory else {
            fail("junction fixture requires an existing directory target")
          }
          @fs.symlink(
            target=@fs.realpath(target_path),
            destination,
            force_symlink=false,
          )
        } else {
          @fs.symlink(target~, destination, force_symlink=true)
        }
        if @async.platform is Windows {
          let (kind, _) = observe_windows_link(destination, root)
          guard kind == (if junction { "Junction" } else { "SymbolicLink" }) else {
            fail("Windows fixture created the wrong link type")
          }
        }
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
        let set = run(
          "touch",
          [flag, "-t", time, destination],
          extra_env=Map([("TZ", "UTC")]),
        )
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
  stat_path : String,
  readlink_path : String,
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
          let result = run(stat_path, [flag, format, child]) catch {
            error =>
              fail("required observation unavailable: \{dimension}: \{error}")
          }
          guard result.status == 0 else {
            fail("host stat failed: \{dimension}")
          }
          metadata[dimension] = @utf8.decode(result.stdout).trim().to_owned()
        }
        "symlink-target" =>
          if kind == SymLink {
            if @async.platform is Windows {
              let (_, target) = observe_windows_link(child, root)
              metadata[dimension] = target
            } else {
              let result = run(readlink_path, [child]) catch {
                error =>
                  fail(
                    "required observation unavailable: symlink-target: \{error}",
                  )
              }
              guard result.status == 0 else { fail("host readlink failed") }
              let target = @utf8.decode(result.stdout)
              metadata[dimension] = if target.has_suffix("\n") {
                target[:target.length() - 1].to_owned()
              } else {
                target
              }
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
    entries.push({
      path: child_relative,
      kind: kind_name(kind),
      content: b"",
      metadata,
    })
    if kind == Directory {
      snapshot_into(
        root, child_relative, entries, observe, stat_path, readlink_path,
      )
    }
  }
}

///|
pub async fn snapshot(
  root : String,
  observe~ : ArrayView[String] = [],
  baseline~ : Bool = false,
  preserve_identity~ : Bool = false,
  stat_path~ : String = "stat",
  readlink_path~ : String = "readlink",
) -> Array[SnapshotEntry] {
  let entries : Array[SnapshotEntry] = []
  snapshot_into(root, "", entries, observe, stat_path, readlink_path)
  // Read content only after every path's metadata is captured. Otherwise
  // reading one hard-link name could change a later alias's observed atime.
  for index in 0..<entries.length() {
    let entry = entries[index]
    if entry.kind == "file" {
      let content = @fs.read_file(
        @path.Path(root).join(Path(entry.path)).to_string(),
        sync_timestamp=baseline && observe.contains("atime"),
      ).binary()
      entries[index] = { ..entry, content, }
    }
  }
  // Only the baseline includes accesses caused by preparing its content
  // observation. Those reads synchronize timestamps before this resampling:
  // otherwise a delayed observer update could look like a candidate mutation.
  // The final snapshot retains atime measured before reading content.
  if baseline && observe.contains("atime") {
    for entry in entries {
      let (s, n) = @fs.atime(
        @path.Path(root).join(Path(entry.path)).to_string(),
        follow_symlink=false,
      )
      entry.metadata["atime"] = "\{s}:\{n}"
    }
  }
  // Independent fixtures compare their identity relations. Before/after
  // rejection checks preserve device/inode values to detect file replacement.
  if !preserve_identity {
    let representatives : Map[String, String] = Map([])
    for entry in entries {
      if entry.metadata.get("identity") is Some(identity) {
        let representative = representatives.get_or_default(
          identity,
          entry.path,
        )
        representatives[identity] = representative
        entry.metadata["identity"] = representative
      }
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
/// Produce a deterministic, byte-oriented representation for backend-pair
/// comparisons. Metadata keys are sorted so the representation is independent
/// of map insertion order.
pub fn snapshot_fingerprint(entries : ArrayView[SnapshotEntry]) -> String {
  let digits = "0123456789abcdef"
  let lines = StringBuilder()
  for entry in entries {
    lines.write(entry.path)
    lines.write("\t")
    lines.write(entry.kind)
    lines.write("\t")
    for byte in entry.content {
      let value = byte.to_int()
      lines.write_char(digits[value >> 4].unsafe_to_char())
      lines.write_char(digits[value & 0xF].unsafe_to_char())
    }
    let keys : Array[String] = []
    for key, _ in entry.metadata {
      keys.push(key)
    }
    keys.sort()
    for key in keys {
      lines.write("\t")
      lines.write(key)
      lines.write("=")
      lines.write(entry.metadata[key])
    }
    lines.write("\n")
  }
  lines.to_string()
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

///|
pub extend SnapshotEntry with @debug.Debug::{to_repr}
