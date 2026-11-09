///|
fn hex(byte : Byte) -> Int32 {
  match byte {
    b'0'..<=b'9' => byte.to_int() - b'0'.to_int()
    b'a'..<=b'f' => byte.to_int() - b'a'.to_int() + 10
    b'A'..<=b'F' => byte.to_int() - b'A'.to_int() + 10
    _ => -1
  }
}

///|
fn request_path(target : String) -> String? {
  guard target.has_prefix("/") else { return None }
  let raw = @utf8.encode(target.split("?").next().unwrap())
  let bytes : Array[Byte] = []
  let mut i = 0
  while i < raw.length() {
    if raw[i] == b'%' {
      guard i + 2 < raw.length() else { return None }
      let high = hex(raw[i + 1])
      let low = hex(raw[i + 2])
      guard high >= 0 && low >= 0 else { return None }
      bytes.push((high * 16 + low).to_byte())
      i += 3
    } else {
      bytes.push(raw[i])
      i += 1
    }
  }
  let path = @utf8.decode(Bytes::from_array(bytes), ignore_bom=false) catch {
    _ => return None
  }
  for c in path {
    if c < ' ' || c == '\u{7f}' || c == '\\' || c == ':' {
      return None
    }
  }
  let parts : Array[String] = []
  for part in path.split("/") {
    if part == "" {
      continue
    }
    // Windows aliases and device names must not bypass regular-file checks.
    let stem = part.split(".").next().unwrap().to_lower().to_owned()
    if part == "." ||
      part == ".." ||
      part.has_suffix(".") ||
      part.has_suffix(" ") ||
      [
        "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6",
        "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7",
        "lpt8", "lpt9",
      ].contains(stem) {
      return None
    }
    parts.push(part.to_owned())
  }
  Some(parts.join("/"))
}

///|
fn inside_root(root : String, path : String) -> Bool {
  let separator = if @async.platform is Windows { "\\" } else { "/" }
  let prefix = if root.has_suffix(separator) { root } else { root + separator }
  path == root || path.has_prefix(prefix)
}

///|
fn mime_type(path : String) -> String {
  match path.split(".").last().unwrap_or("").to_lower() {
    "html" | "htm" => "text/html"
    "css" => "text/css"
    "js" | "mjs" => "text/javascript"
    "json" | "map" => "application/json"
    "txt" | "md" | "log" => "text/plain"
    "xml" => "application/xml"
    "wasm" => "application/wasm"
    "svg" => "image/svg+xml"
    "png" => "image/png"
    "jpg" | "jpeg" => "image/jpeg"
    "gif" => "image/gif"
    "webp" => "image/webp"
    "avif" => "image/avif"
    "ico" => "image/vnd.microsoft.icon"
    "pdf" => "application/pdf"
    "zip" => "application/zip"
    "gz" => "application/gzip"
    "woff" => "font/woff"
    "woff2" => "font/woff2"
    "ttf" => "font/ttf"
    "otf" => "font/otf"
    "mp3" => "audio/mpeg"
    "ogg" => "audio/ogg"
    "wav" => "audio/wav"
    "mp4" => "video/mp4"
    "webm" => "video/webm"
    _ => "application/octet-stream"
  }
}

///|
async fn serve_file(
  root : String,
  request : @http.Request,
  connection : @http.ServerConnection,
  port~ : Int32,
  token? : String,
) -> Unit {
  let headers : Map[@http.CaseInsensitiveString, String] = {
    "Content-Length": "0",
  }
  let target = if token is Some(token) {
    headers["Cache-Control"] = "no-store"
    headers["Referrer-Policy"] = "no-referrer"
    guard request.headers.get("host") == Some("127.0.0.1:\{port}") else {
      connection.send_response(403, "Forbidden", extra_headers=headers)
      return
    }
    guard request.path.strip_prefix("/\{token}/") is Some(path) else {
      connection.send_response(404, "Not Found", extra_headers=headers)
      return
    }
    "/" + path.to_owned()
  } else {
    request.path
  }
  guard request.meth is (Get | Head) else {
    headers["Allow"] = "GET, HEAD"
    connection.send_response(405, "Method Not Allowed", extra_headers=headers)
    return
  }
  guard request_path(target) is Some(relative) else {
    connection.send_response(400, "Bad Request", extra_headers=headers)
    return
  }
  // Resolve and check the actual target, including index.html symlinks.
  // Path-based public APIs cannot close concurrent replacement races.
  let opened = try {
    let mut path = @fs.realpath(root + "/" + relative)
    guard inside_root(root, path) else { fail("outside root") }
    let index = @fs.kind(path) is Directory
    if index {
      path = @fs.realpath(path + "/index.html")
      guard inside_root(root, path) else { fail("outside root") }
    }
    guard @fs.kind(path) is Regular else { fail("not a regular file") }
    Some((@fs.open(path, mode=ReadOnly), index))
  } catch {
    _ => None
  }
  guard opened is Some((file, index)) else {
    connection.send_response(404, "Not Found", extra_headers=headers)
    return
  }
  defer file.close()
  let raw_path = request.path.split("?").next().unwrap()
  if index && !raw_path.has_suffix("/") {
    headers["Location"] = "/" +
      raw_path.trim_start(chars="/").to_owned() +
      "/" +
      request.path[raw_path.length():].to_owned()
    connection.send_response(301, "Moved Permanently", extra_headers=headers)
    return
  }
  guard file.kind() is Regular else {
    connection.send_response(404, "Not Found", extra_headers=headers)
    return
  }
  let size = file.size()
  let mime = mime_type(if index { "index.html" } else { relative })
  headers["Content-Length"] = size.to_string()
  headers["Content-Type"] = if token is Some(_) && mime.has_prefix("text/") {
    mime + "; charset=utf-8"
  } else {
    mime
  }
  headers["X-Content-Type-Options"] = "nosniff"
  connection.send_response(200, "OK", extra_headers=headers)
  if request.meth is Head {
    return
  }
  let buffer : FixedArray[Byte] = FixedArray::make(65536, 0)
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  let mut remaining = size
  while remaining > 0 {
    let n = file.read(
      buffer,
      max_len=remaining.min(buffer.length().to_int64()).to_int(),
    )
    guard n > 0 else { fail("file shortened during response") }
    connection.write(bytes[:n])
    remaining -= n.to_int64()
  }
}
