///|
fn git_utf8(bytes : BytesView, context : String) -> String raise {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ =>
      fail("scope Git " + context + " contains an invalid UTF-8 path or header")
  }
}

///|
fn git_oid(value : String, zero~ : Bool = false) -> Bool {
  (value.length() == 40 || value.length() == 64) &&
  value.iter().all(char => char is ('0'..<='9' | 'a'..<='f')) &&
  (zero || value.iter().any(char => char != '0'))
}

///|
fn git_mode(value : String, absent~ : Bool = false) -> Bool {
  value is ("100644" | "100755" | "120000" | "160000") ||
  (absent && value == "000000")
}

///|
fn git_safe_path(value : String) -> Unit raise {
  guard !value.is_empty() &&
    !value.has_prefix("/") &&
    !value.contains("\\") &&
    !value.contains(":") &&
    !value.contains("\u0000") else {
    fail("scope Git requires an unambiguous repository-relative path: " + value)
  }
  for component in value.split("/") {
    guard component != "" &&
      component != "." &&
      component != ".." &&
      component.to_lower() != ".git" else {
      fail("scope Git rejects an unsafe path component: " + value)
    }
  }
}

///|
fn git_nul_records(bytes : Bytes) -> Array[Bytes] raise {
  let records : Array[Bytes] = []
  if bytes.is_empty() {
    return records
  }
  guard bytes[bytes.length() - 1] == b'\x00' else {
    fail("scope Git NUL-delimited output is truncated")
  }
  let mut start = 0
  for index in 0..<bytes.length() {
    if bytes[index] == b'\x00' {
      guard index > start else {
        fail("scope Git NUL-delimited output contains an empty record")
      }
      records.push(bytes[start:index].to_owned())
      start = index + 1
    }
  }
  records
}

///|
fn git_tree_entries(bytes : Bytes) -> Array[TreeFile] raise {
  let files : Array[TreeFile] = []
  let paths : Set[String] = Set([])
  for record in git_nul_records(bytes) {
    let text = git_utf8(record[:], "ls-tree record")
    guard text.split_once("\t") is Some((header, path_view)) else {
      fail("scope Git ls-tree record has no path separator")
    }
    let fields = header.split(" ").collect()
    guard fields is [mode, kind, blob] &&
      git_mode(mode.to_owned()) &&
      git_oid(blob.to_owned()) else {
      fail("scope Git ls-tree record has malformed metadata")
    }
    guard kind == "blob" && mode != "160000" else {
      fail("scope Git cannot bind a submodule or non-blob tree entry")
    }
    let path = path_view.to_owned()
    git_safe_path(path)
    guard !paths.contains(path) else {
      fail("scope Git ls-tree contains a duplicate path: " + path)
    }
    paths.add(path)
    files.push({
      path,
      mode: mode.to_owned(),
      blob: blob.to_owned(),
      content: b"",
    })
  }
  files.sort_by_key(file => file.path)
  files
}

///|
fn git_batch_blobs(
  bytes : Bytes,
  expected : Array[String],
) -> Array[Bytes] raise {
  let contents : Array[Bytes] = []
  let mut offset = 0
  for blob in expected {
    let mut newline = offset
    while newline < bytes.length() && bytes[newline] != b'\n' {
      newline += 1
    }
    guard newline < bytes.length() else {
      fail("scope Git cat-file batch header is truncated")
    }
    let fields = git_utf8(bytes[offset:newline], "cat-file header")
      .split(" ")
      .map(field => field.to_owned())
      .collect()
    guard fields is [actual, kind, size_text] &&
      actual == blob &&
      kind == "blob" &&
      !size_text.is_empty() &&
      (size_text == "0" || !size_text.has_prefix("0")) else {
      fail("scope Git cat-file returned an unexpected object header")
    }
    let mut size = 0
    for char in size_text {
      guard char is ('0'..<='9') else {
        fail("scope Git cat-file returned a nondecimal object size")
      }
      let digit = char.to_int() - 48
      guard size <= (bytes.length() - digit) / 10 else {
        fail("scope Git cat-file object size exceeds captured output")
      }
      size = size * 10 + digit
    }
    offset = newline + 1
    guard size < bytes.length() - offset && bytes[offset + size] == b'\n' else {
      fail("scope Git cat-file blob or separator is truncated")
    }
    contents.push(bytes[offset:offset + size].to_owned())
    offset += size + 1
  }
  guard offset == bytes.length() else {
    fail("scope Git cat-file batch contains trailing data")
  }
  contents
}

///|
fn git_change_status(value : String) -> Bool {
  if value is ("A" | "D" | "M" | "T") {
    return true
  }
  guard value.length() >= 2 &&
    value.length() <= 4 &&
    (value.has_prefix("R") || value.has_prefix("C")) else {
    return false
  }
  let score = value[1:].to_owned()
  let mut percentage = 0
  for char in score {
    guard char is ('0'..<='9') else { return false }
    percentage = percentage * 10 + char.to_int() - 48
  }
  percentage <= 100
}

///|
fn git_raw_changes(bytes : Bytes) -> Array[GitChange] raise {
  let records = git_nul_records(bytes)
  let changes : Array[GitChange] = []
  let old_paths : Set[String] = Set([])
  let new_paths : Set[String] = Set([])
  let mut index = 0
  while index < records.length() {
    let header = git_utf8(records[index][:], "raw diff header")
    guard header.has_prefix(":") else {
      fail("scope Git raw diff header has no colon")
    }
    let fields = header[1:].split(" ").map(x => x.to_owned()).collect()
    guard fields is [old_mode, new_mode, old_blob, new_blob, status] &&
      git_mode(old_mode, absent=true) &&
      git_mode(new_mode, absent=true) &&
      git_oid(old_blob, zero=true) &&
      git_oid(new_blob, zero=true) &&
      old_blob.length() == new_blob.length() &&
      git_change_status(status) else {
      fail("scope Git raw diff contains malformed modes, objects or status")
    }
    let old_absent = old_mode == "000000"
    let new_absent = new_mode == "000000"
    let status_matches = match status {
      "A" => old_absent && !new_absent
      "D" => !old_absent && new_absent
      _ => !old_absent && !new_absent
    }
    guard old_absent == old_blob.iter().all(char => char == '0') &&
      new_absent == new_blob.iter().all(char => char == '0') &&
      status_matches else {
      fail("scope Git raw diff status disagrees with absent object metadata")
    }
    index += 1
    guard index < records.length() else {
      fail("scope Git raw diff is missing a path")
    }
    let first = git_utf8(records[index][:], "raw diff path")
    git_safe_path(first)
    index += 1
    let paired = status.has_prefix("R") || status.has_prefix("C")
    let second = if paired {
      guard index < records.length() else {
        fail("scope Git raw rename or copy is missing its destination")
      }
      let destination = git_utf8(records[index][:], "raw diff destination")
      git_safe_path(destination)
      guard destination != first else {
        fail("scope Git raw rename or copy has identical paths")
      }
      index += 1
      destination
    } else {
      first
    }
    let old_path = if old_absent { "" } else { first }
    let new_path = if new_absent { "" } else { second }
    if old_path != "" && !status.has_prefix("C") {
      guard !old_paths.contains(old_path) else {
        fail("scope Git raw diff repeats an old path: " + old_path)
      }
      old_paths.add(old_path)
    }
    if new_path != "" {
      guard !new_paths.contains(new_path) else {
        fail("scope Git raw diff repeats a new path: " + new_path)
      }
      new_paths.add(new_path)
    }
    changes.push({
      status,
      old_path,
      new_path,
      old_mode,
      new_mode,
      old_blob,
      new_blob,
    })
  }
  changes.sort_by_key(change => change.old_path + "\u0000" + change.new_path)
  changes
}
