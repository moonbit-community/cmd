///|
/// Preserve raw success observations in one stream before removing work files.
pub async fn compact_evidence(directory : String) -> String {
  let output = directory + ".jsonl"
  guard !@fs.exists(output) else {
    fail("evidence stream already exists: " + output)
  }
  let entries = snapshot(directory, observe=["symlink-target"])
  guard !entries.is_empty() else {
    fail("required success observations are empty")
  }
  let stream = @fs.open(output, mode=WriteOnly, create_mode=CreateNew)
  defer stream.close()
  for entry in entries {
    let row : Json = {
      "path": entry.path,
      "kind": entry.kind,
      "content_hex": @crypto.bytes_to_hex_string(entry.content),
      "metadata": Json(entry.metadata),
    }
    stream.write(@utf8.encode(row.stringify() + "\n"))
  }
  // Any read, write or cleanup failure propagates; original files survive until
  // every observation has been written successfully.
  @fs.rmdir(directory, recursive=true)
  output
}
