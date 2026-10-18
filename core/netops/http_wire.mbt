///|
priv enum WireBody {
  Finished
  Fixed(Int64)
  UntilClose
  ChunkSize
  ChunkData(Int64)
  ChunkSeparator
  Trailers
}

///|
priv struct HttpWire {
  client : @http.Client
  mut pending : Bytes
  mut position : Int32
  mut body : WireBody
  mut header_bytes : Int64
  mut request_remaining : Int64?
  mut request_chunked : Bool
  mut request_payload_bytes : Int64
}

///|
async fn HttpWire::new(client : @http.Client) -> HttpWire {
  // Transition before any HTTP request: the connection already includes TLS
  // and any proxy tunnel, while no response bytes can have been discarded.
  client.enter_passthrough_mode()
  {
    client,
    pending: b"",
    position: 0,
    body: Finished,
    header_bytes: 0L,
    request_remaining: None,
    request_chunked: false,
    request_payload_bytes: 0L,
  }
}

///|
fn HttpWire::close(self : HttpWire) -> Unit {
  self.client.close()
}

///|
async fn HttpWire::fill(self : HttpWire) -> Bool {
  if self.position < self.pending.length() {
    return true
  }
  match self.client.read_some(max_len=65536) {
    Some(bytes) => {
      self.pending = bytes
      self.position = 0
      true
    }
    None => false
  }
}

///|
async fn HttpWire::line(self : HttpWire, header~ : Bool = false) -> String {
  let bytes : Array[Byte] = []
  for ;; {
    guard self.fill() else { raise @io.ReaderClosed }
    let byte = self.pending[self.position]
    self.position += 1
    if header {
      self.header_bytes += 1L
      guard self.header_bytes <= 1048576L else {
        raise transfer_error(
          ReceiveFailure,
          "HTTP response headers exceed 1048576 bytes",
        )
      }
    }
    if byte == b'\n' {
      guard bytes.last() == Some(b'\r') else {
        raise transfer_error(ReceiveFailure, "HTTP line has no CRLF terminator")
      }
      ignore(bytes.pop())
      return @utf8.decode(Bytes::from_array(bytes)) catch {
        _ => raise transfer_error(ReceiveFailure, "invalid HTTP header text")
      }
    }
    bytes.push(byte)
    // Bound untrusted protocol metadata independently of streamed body size.
    guard bytes.length() <= 65536 else {
      raise transfer_error(ReceiveFailure, "HTTP line exceeds 65536 bytes")
    }
  }
}

///|
fn wire_token(value : String) -> Bool {
  if value == "" {
    return false
  }
  for character in value {
    match character {
      'a'..<='z'
      | 'A'..<='Z'
      | '0'..<='9'
      | '!'
      | '#'
      | '$'
      | '%'
      | '&'
      | '\''
      | '*'
      | '+'
      | '-'
      | '.'
      | '^'
      | '_'
      | '`'
      | '|'
      | '~' => ()
      _ => return false
    }
  }
  true
}

///|
fn wire_field(line : String) -> (String, String) raise TransferError {
  guard line.find(":") is Some(colon) && wire_token(line[:colon].to_owned()) else {
    raise transfer_error(ReceiveFailure, "invalid HTTP header field")
  }
  let value = line[colon + 1:]
  for character in value {
    if (character < ' ' && character != '\t') || character == '\u007f' {
      raise transfer_error(ReceiveFailure, "invalid HTTP header field value")
    }
  }
  (line[:colon].to_owned(), value.trim(chars=" \t").to_owned())
}

///|
fn wire_content_length(value : String) -> Int64 raise TransferError {
  guard value != "" else {
    raise transfer_error(ReceiveFailure, "empty Content-Length")
  }
  for character in value {
    guard character >= '0' && character <= '9' else {
      raise transfer_error(ReceiveFailure, "invalid Content-Length")
    }
  }
  @string.parse_int64(value) catch {
    _ => raise transfer_error(ReceiveFailure, "Content-Length is too large")
  }
}

///|
async fn HttpWire::response(
  self : HttpWire,
  request_method : HttpMethod,
  profile~ : TransferProfile = StrictProfile,
) -> @http.Response {
  for interim = 0; ; interim = interim + 1 {
    guard interim <= 128 else {
      raise transfer_error(ReceiveFailure, "too many informational responses")
    }
    let status = self.line(header=true)
    guard status.length() >= 12 &&
      (status.has_prefix("HTTP/1.1 ") || status.has_prefix("HTTP/1.0 ")) &&
      (status.length() == 12 || status.code_unit_at(12) == ' ') else {
      raise transfer_error(ReceiveFailure, "invalid HTTP response status line")
    }
    let code_text = status[9:12].to_owned()
    let code = wire_content_length(code_text).to_int()
    guard code >= 100 && code <= 999 else {
      raise transfer_error(ReceiveFailure, "invalid HTTP response status code")
    }
    let reason = if status.length() == 12 { "" } else { status[13:].to_owned() }
    let headers : Map[@http.CaseInsensitiveString, String] = Map([])
    let cookies : Array[@http.Cookie] = []
    for fields = 0; ; fields = fields + 1 {
      let line = self.line(header=true) catch {
        @io.ReaderClosed if profile != StrictProfile && code == 200 => break
        error => raise error
      }
      if line == "" {
        break
      }
      guard fields < 1024 else {
        raise transfer_error(
          ReceiveFailure,
          "HTTP response headers exceed limits",
        )
      }
      let (name, value) = wire_field(line)
      if name.to_lower() == "set-cookie" {
        cookies.push(wire_cookie(value))
      } else {
        let key = @http.CaseInsensitiveString(name)
        headers[key] = match headers.get(key) {
          None => value
          Some(previous) => previous + "," + value
        }
      }
    }
    if code >= 100 && code < 200 && code != 101 {
      continue
    }
    let response : @http.Response = { code, reason, headers, cookies, }
    if !response_has_body(code, request_method) {
      self.body = Finished
    } else if headers.get("Transfer-Encoding") is Some(encoding) {
      guard encoding.to_lower() == "chunked" else {
        raise transfer_error(ReceiveFailure, "unsupported HTTP transfer coding")
      }
      self.body = ChunkSize
    } else if headers.get("Content-Length") is Some(value) {
      let length = wire_content_length(value)
      self.body = Fixed(length)
    } else {
      self.body = UntilClose
    }
    return response
  }
}

///|
async fn HttpWire::read_some(
  self : HttpWire,
  max_len~ : Int32,
  profile~ : TransferProfile = StrictProfile,
) -> Bytes? {
  for ;; {
    match self.body {
      Finished | Fixed(0L) => return None
      Fixed(remaining) | ChunkData(remaining) => {
        guard self.fill() else {
          if profile == WgetProfile && self.body is ChunkData(_) {
            self.body = Finished
            return None
          }
          raise @io.ReaderClosed
        }
        let length = remaining
          .min(max_len.to_int64())
          .to_int()
          .min(self.pending.length() - self.position)
        let bytes = self.pending[self.position:self.position + length].to_owned()
        self.position += length
        self.body = match self.body {
          Fixed(_) => Fixed(remaining - length.to_int64())
          _ =>
            if remaining == length.to_int64() {
              ChunkSeparator
            } else {
              ChunkData(remaining - length.to_int64())
            }
        }
        // Payload is observable before the next read validates chunk framing.
        return Some(bytes)
      }
      UntilClose => {
        guard self.fill() else { return None }
        let length = max_len.min(self.pending.length() - self.position)
        let bytes = self.pending[self.position:self.position + length].to_owned()
        self.position += length
        return Some(bytes)
      }
      ChunkSize => {
        let line = self.line()
        let raw = match line.find(";") {
          Some(index) => {
            wire_chunk_extensions(line[index:].to_owned())
            line[:index].trim_end(chars=" \t").to_owned()
          }
          None => line
        }
        guard raw != "" else {
          raise transfer_error(ReceiveFailure, "empty HTTP chunk size")
        }
        for character in raw {
          guard character is ('0'..<='9' | 'a'..<='f' | 'A'..<='F') else {
            raise transfer_error(ReceiveFailure, "invalid HTTP chunk size")
          }
        }
        let length = @string.parse_int64(raw, base=16) catch {
          _ =>
            raise transfer_error(ReceiveFailure, "HTTP chunk size is too large")
        }
        self.body = if length == 0L { Trailers } else { ChunkData(length) }
      }
      ChunkSeparator => {
        for expected in [b'\r', b'\n'] {
          guard self.fill() else { raise @io.ReaderClosed }
          let actual = self.pending[self.position]
          self.position += 1
          guard actual == expected else {
            raise transfer_error(
              ReceiveFailure,
              "invalid HTTP chunk terminator",
            )
          }
        }
        self.body = ChunkSize
      }
      Trailers =>
        for fields = 0; ; fields = fields + 1 {
          let line = self.line() catch {
            @io.ReaderClosed if profile == WgetProfile => {
              self.body = Finished
              return None
            }
            error => raise error
          }
          if line == "" {
            self.body = Finished
            return None
          }
          guard fields < 1024 else {
            raise transfer_error(ReceiveFailure, "too many HTTP trailer fields")
          }
          let (name, _) = wire_field(line)
          if name.to_lower() == "set-cookie" {
            raise transfer_error(
              ReceiveFailure,
              "Set-Cookie is not supported in HTTP trailers",
            )
          }
        }
    }
  }
}
