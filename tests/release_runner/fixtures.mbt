///|
fn decode_hex(value : String, _label : String) -> Bytes raise Failure {
  guard value.length() % 2 == 0 else {
    fail("\{_label}: hexadecimal byte string has odd length")
  }
  let bytes : Array[Byte] = []
  for index = 0; index < value.length(); index = index + 2 {
    let high = hex_nibble(value[index].to_char().unwrap())
    let low = hex_nibble(value[index + 1].to_char().unwrap())
    guard high is Some(high) && low is Some(low) else {
      fail("\{_label}: invalid hexadecimal byte at offset \{index}")
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  Bytes::from_array(bytes)
}

///|
fn hex_nibble(char : Char) -> Int? {
  match char {
    '0'..='9' => Some(char.to_int() - '0'.to_int())
    'a'..='f' => Some(char.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(char.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
fn expand_args(
  args : ArrayView[String],
  root : String,
  http_base? : String,
) -> Array[String] {
  args.map(arg => expand_text(arg, root, http_base?))
}

///|
fn expand_text(value : String, root : String, http_base? : String) -> String {
  let expanded = value.replace_all(old="${WORK}", new=root)
  match http_base {
    Some(base) => expanded.replace_all(old="${HTTP_BASE}", new=base)
    None => expanded
  }
}

///|
fn expand_fixture_content(content : Bytes, http_base? : String) -> Bytes {
  guard http_base is Some(base) else { return content }
  let text = @utf8.decode(content) catch { _ => return content }
  if !text.contains("${HTTP_BASE}") {
    return content
  }
  @utf8.encode(text.replace_all(old="${HTTP_BASE}", new=base))
}

///|
async fn prepare_fixture(
  root : String,
  fixture : ReleaseCase,
  http_base? : String,
) -> Unit {
  for file in fixture.files {
    let destination = @path.Path(root).join(Path(file.path)).to_string()
    let parent = @path.Path(destination).dirname().to_string()
    if !@fs.exists(parent) {
      @fs.mkdir(parent, recursive=true)
    }
    match file.kind {
      Some("symlink") => @fs.symlink(target=file.target.unwrap(), destination)
      _ =>
        @fs.write_file(
          destination,
          expand_fixture_content(
            decode_hex(file.content_hex, fixture.id + ":" + file.path),
            http_base?,
          ),
        )
    }
  }
}

///|
fn is_network_case(fixture : ReleaseCase) -> Bool {
  fixture.args.any(arg => {
    arg.contains("${HTTP_BASE}") || arg.contains("${HTTPS_BASE}")
  }) ||
  fixture.files.any(file => {
    file.content_hex.to_lower().contains("247b485454505f424153457d")
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
priv struct SnapshotEntry {
  path : String
  kind : String
  content : Bytes
}

///|
async fn snapshot_into(
  root : String,
  relative : String,
  entries : Array[SnapshotEntry],
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
    let content = if kind == Regular {
      @fs.read_file(child).binary()
    } else {
      b""
    }
    entries.push({ path: child_relative, kind: kind_name(kind), content, })
    if kind == Directory {
      snapshot_into(root, child_relative, entries)
    }
  }
}

///|
async fn snapshot(root : String) -> Array[SnapshotEntry] {
  let entries : Array[SnapshotEntry] = []
  snapshot_into(root, "", entries)
  entries
}

///|
fn snapshots_equal(
  left : ArrayView[SnapshotEntry],
  right : ArrayView[SnapshotEntry],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index = 0; index < left.length(); index = index + 1 {
    if left[index].path != right[index].path ||
      left[index].kind != right[index].kind ||
      !@testkit.bytes_equal(left[index].content, right[index].content) {
      return false
    }
  }
  true
}

///|
fn normalize_text(
  data : Bytes,
  field : String,
  rules : ArrayView[Normalization],
  temporary_root : String,
) -> Bytes {
  let applies = rules.any(rule => rule.field == field)
  if !applies {
    return data
  }
  let mut text = @utf8.decode(data) catch { _ => return data }
  for rule in rules {
    if rule.field == field {
      match rule.rule {
        "temporary-path" =>
          text = text.replace_all(old=temporary_root, new="<TMP>")
        "path-separator" => text = text.replace_all(old="\\", new="/")
        "working-directory" => {
          text = text.replace_all(old=temporary_root, new="<WORK>")
          text = text.replace_all(old="/work", new="<WORK>")
        }
        _ => ()
      }
    }
  }
  @utf8.encode(text)
}

///|
fn controlled_environment(extra : Map[String, String]) -> Map[String, String] {
  let result : Map[String, String] = { "LC_ALL": "C", "LANG": "C", "TZ": "UTC" }
  for name, value in extra {
    result[name] = value
  }
  result
}
