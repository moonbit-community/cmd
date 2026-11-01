///|
async fn real_http_output_errors(
  source : String,
  output : String,
) -> Array[String] {
  if files_equal(source, output) {
    []
  } else {
    [
      "HTTP response differs from the complete selected source; rejected or truncated transfers cannot qualify",
    ]
  }
}

///|
async fn run_real_http_fixture(
  server : @http.Server,
  source : Ref[String?],
) -> Unit {
  server.run_forever() <| ((request, body, connection) => {
    guard source.val is Some(path) else {
      fail("real HTTP fixture has no selected frozen source")
    }
    let input = @fs.open(path, mode=ReadOnly)
    defer input.close()
    let size = input.size()
    if request.path == "/real-upload/POST" || request.path == "/real-upload/PUT" {
      let request_method = @testkit.oracle_request_name(request)
      if request.path != "/real-upload/" + request_method {
        connection
        ..send_response(405, "Method Not Allowed", extra_headers={
          "Content-Length": "0",
        })
        .end_response()
        return
      }
      let buffer = FixedArray::make(65536, b'\x00')
      let bytes = buffer.unsafe_reinterpret_as_bytes()
      let mut offset = 0L
      let mut equal = true
      while body.read(buffer) is count && count > 0 {
        if offset + count.to_int64() > size ||
          input.read_exactly_at(count, position=offset) !=
          bytes[:count].to_owned() {
          equal = false
        }
        offset += count.to_int64()
      }
      if !equal || offset != size {
        connection
        ..send_response(400, "Bad Request", extra_headers={
          "Content-Length": "0",
        })
        .end_response()
        return
      }
    } else if request.path != "/real-source" ||
      (request.meth != @http.Get && request.meth != @http.Head) {
      connection
      ..send_response(404, "Not Found", extra_headers={ "Content-Length": "0" })
      .end_response()
      return
    }
    connection.send_response(200, "OK", extra_headers={
      "Content-Length": size.to_string(),
    })
    if request.meth != @http.Head {
      let buffer = FixedArray::make(65536, b'\x00')
      let bytes = buffer.unsafe_reinterpret_as_bytes()
      while input.read(buffer) is count && count > 0 {
        connection.write(bytes[:count])
      }
    }
    connection.end_response()
  })
}
