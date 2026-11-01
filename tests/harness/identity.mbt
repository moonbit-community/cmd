///|
/// SHA-256 verifies the pinned upstream image inputs and version inventory.
pub fn sha256_bytes(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
/// Hash UTF-8 text without normalizing its bytes first.
pub fn sha256_text(text : String) -> String {
  sha256_bytes(@utf8.encode(text))
}

///|
/// Return canonical JSON with object keys sorted recursively.  This avoids
/// map iteration order changing saved observations or oracle comparisons.
pub fn canonical_json(value : Json) -> String {
  match value {
    Null => "null"
    True => "true"
    False => "false"
    Number(_, ..) => value.stringify()
    String(value) => Json::string(value).stringify()
    Array(items) =>
      "[" + items.map(item => canonical_json(item)).join(",") + "]"
    Object(fields) => {
      let keys = fields.keys().collect()
      keys.sort()
      let entries = keys.map(key => {
        Json::string(key).stringify() + ":" + canonical_json(fields[key])
      })
      "{" + entries.join(",") + "}"
    }
  }
}

///|
/// Hash JSON after canonicalizing object key order.
pub fn json_digest(value : Json) -> String {
  sha256_text(canonical_json(value))
}

///|
/// Hash a single file.  A missing or unreadable path returns an empty digest
/// so callers can distinguish an unavailable input from a valid hash.
pub async fn file_digest(path : String) -> String {
  guard @fs.exists(path) else { return "" }
  let data = @fs.read_file(path) catch { _ => return "" }
  sha256_bytes(data.binary())
}
