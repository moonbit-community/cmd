///|
async fn resource_sha256(path : String) -> String {
  let input = @fs.open(path, mode=ReadOnly)
  defer input.close()
  let hash = @crypto.SHA256::new()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  while input.read(buffer) is length && length > 0 {
    hash.update(bytes[:length])
  }
  @crypto.bytes_to_hex_string(hash.finalize())
}

///|
async fn copy_content_range(
  source : @fs.File,
  output : @fs.File,
  start : Int64,
  end : Int64,
) -> Unit {
  guard start >= 0L && end >= start && end <= source.size() else {
    fail("invalid resource content range")
  }
  let mut offset = start
  while offset < end {
    let length = (end - offset).min(65536L).to_int()
    output.write(source.read_exactly_at(length, position=offset))
    offset += length.to_int64()
  }
}

///|
struct ContentEdit {
  at : Int64
  remove_bytes : Int64
  insert : Bytes
}

///|
async fn write_content_diff(
  source_path : String,
  changed : String,
  features : ContentInput,
  regime : String,
) -> Json {
  guard features.rows >= 12L else {
    fail("resource diff content modes need at least twelve records")
  }
  let source = @fs.open(source_path, mode=ReadOnly)
  defer source.close()
  let output = @fs.create(changed)
  defer output.close()
  let edits : Array[ContentEdit] = []
  if regime == "sparse-interior-insert-delete" {
    let insert_at = content_row_offset(features.rows / 3L, features.mixed)
    let delete_row = features.rows * 2L / 3L
    let delete_at = content_row_offset(delete_row, features.mixed)
    let delete_end = content_row_offset(delete_row + 2L, features.mixed).min(
      features.bytes,
    )
    edits.push({
      at: insert_at,
      remove_bytes: 0L,
      insert: b"inserted sparse resource record\n",
    })
    edits.push({
      at: delete_at,
      remove_bytes: delete_end - delete_at,
      insert: b"",
    })
  } else if regime == "distributed-interior-edits" {
    guard features.rows > 2050L else {
      fail("distributed resource diff needs more than 2050 records")
    }
    let mut event = 0L
    for row = 2048L; row + 2L < features.rows; row = row + 4096L {
      let at = content_row_offset(row, features.mixed)
      let remove_bytes = if event % 5L == 0L {
        content_row_offset(row + 2L, features.mixed) - at
      } else {
        1L
      }
      let insert = if event % 5L == 0L {
        b"replacement distributed resource record\n"
      } else if event % 3L == 0L {
        b"inserted distributed resource record\nX"
      } else {
        b"X"
      }
      edits.push({ at, remove_bytes, insert, })
      event += 1L
    }
  } else {
    guard regime == "distinct-equal-content" else {
      fail("unknown resource diff content regime")
    }
  }
  let events : Array[Json] = []
  let mut offset = 0L
  for edit in edits {
    guard edit.at >= offset &&
      edit.at > 0L &&
      edit.at + edit.remove_bytes < features.bytes else {
      fail("resource diff edits must be nonoverlapping and interior")
    }
    copy_content_range(source, output, offset, edit.at)
    output.write(edit.insert)
    offset = edit.at + edit.remove_bytes
    events.push({
      "source_offset": edit.at.to_string(),
      "removed_bytes": edit.remove_bytes.to_string(),
      "inserted_bytes": edit.insert.length(),
    })
  }
  copy_content_range(source, output, offset, features.bytes)
  {
    "regime": regime,
    "same_file_identity": false,
    "source_bytes": features.bytes.to_string(),
    "source_rows": features.rows.to_string(),
    "events": events,
    "input_transport": "distinct-named-regular-files",
    "record_layout": if features.mixed {
      "mixed-short32/64/96/128/512/4096"
    } else {
      "ordinary80"
    },
  }
}

///|
// Verify every fragment independently against its declared source interval,
// including the nonempty final tail after the last repeated interior marker.
async fn content_fragments_match(
  source_path : String,
  effects : String,
  features : ContentInput,
) -> Bool {
  let names = @fs.readdir(effects, sort=true)
  if names.length() != features.section_offsets.length() + 1 {
    return false
  }
  let source = @fs.open(source_path, mode=ReadOnly)
  defer source.close()
  let mut offset = 0L
  for index, name in names {
    let suffix = index.to_string()
    if name != "part-" + "0".repeat((6 - suffix.length()).max(0)) + suffix {
      return false
    }
    let end = if index < features.section_offsets.length() {
      features.section_offsets[index]
    } else {
      features.bytes
    }
    let fragment = @fs.open(effects + "/" + name, mode=ReadOnly)
    defer fragment.close()
    if fragment.size() != end - offset || end <= offset {
      return false
    }
    let mut position = 0L
    while position < end - offset {
      let length = (end - offset - position).min(65536L).to_int()
      if fragment.read_exactly_at(length, position~) !=
        source.read_exactly_at(length, position=offset + position) {
        return false
      }
      position += length.to_int64()
    }
    offset = end
  }
  offset == features.bytes
}

///|
async fn equal_files(left : String, right : String) -> Bool {
  let a = @fs.open(left, mode=ReadOnly)
  defer a.close()
  let b = @fs.open(right, mode=ReadOnly)
  defer b.close()
  let size = a.size()
  if size != b.size() {
    return false
  }
  let mut position = 0L
  while position < size {
    let length = (size - position).min(65536).to_int()
    if a.read_exactly_at(length, position~) !=
      b.read_exactly_at(length, position~) {
      return false
    }
    position += length.to_int64()
  }
  true
}

///|
async fn single_record_fragments_match(
  source : String,
  effects : String,
) -> Bool {
  @fs.readdir(effects, sort=true) == ["part-00", "part-01"] &&
  @fs.file_size(effects + "/part-00") == 0L &&
  equal_files(source, effects + "/part-01")
}

///|
async fn equal_effects(left : String, right : String) -> Bool {
  let a = @fs.readdir(left, sort=true)
  let b = @fs.readdir(right, sort=true)
  if a != b {
    return false
  }
  for name in a {
    if !equal_files(left + "/" + name, right + "/" + name) {
      return false
    }
  }
  true
}
