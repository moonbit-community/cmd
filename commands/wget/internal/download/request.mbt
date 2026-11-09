///|
fn validate_options(options : Options) -> Unit raise TransferError {
  if options.connect_timeout_ms <= 0 || options.idle_timeout_ms <= 0 {
    raise transfer_error(TimeoutFailure, "timeouts must be greater than zero")
  }
  if options.resume_from is Some(offset) && offset < 0L {
    raise transfer_error(ProtocolFailure, "resume offset must not be negative")
  }
  match options.redirects {
    FollowRedirects(limit) if limit < 0 =>
      raise transfer_error(
        RedirectFailure,
        "redirect limit must not be negative",
      )
    _ => ()
  }
}

///|
priv struct PreparedHeaders {
  persistent : HeaderFields
  per_request : HeaderFields
  authorization_supplied : Bool
}

///|
priv struct HeaderFields {
  fields : Array[HttpHeader]
}

///|
fn HeaderFields::get(self : HeaderFields, name : String) -> String? {
  let name = name.to_lower()
  for header in self.fields {
    if header.name.to_lower() == name {
      return Some(header.value)
    }
  }
  None
}

///|
fn HeaderFields::contains(self : HeaderFields, name : String) -> Bool {
  self.get(name) is Some(_)
}

///|
fn HeaderFields::set(
  self : HeaderFields,
  name : String,
  value : String,
) -> Unit {
  let lower = name.to_lower()
  for index in 0..<self.fields.length() {
    if self.fields[index].name.to_lower() == lower {
      self.fields[index] = @netops.http_header(self.fields[index].name, value)
      return
    }
  }
  self.fields.push(@netops.http_header(name, value))
}

///|
fn uses_basic_authentication(value : String) -> Bool {
  let value = value.to_lower().trim_start()
  value == "basic" || value.has_prefix("basic ") || value.has_prefix("basic\t")
}

///|
fn has_basic_challenge(value : String) -> Bool {
  let mut part = StringBuilder()
  let mut quoted = false
  let mut escaped = false
  for character in value {
    if quoted {
      part.write_char(character)
      if escaped {
        escaped = false
      } else if character == '\\' {
        escaped = true
      } else if character == '"' {
        quoted = false
      }
    } else if character == ',' {
      if basic_challenge_part(part.to_string()) {
        return true
      }
      part = StringBuilder()
    } else {
      part.write_char(character)
      if character == '"' {
        quoted = true
      }
    }
  }
  !quoted && basic_challenge_part(part.to_string())
}

///|
fn basic_challenge_part(value : String) -> Bool {
  let value = value.trim().to_owned()
  uses_basic_authentication(value) && !value[5:].trim_start().has_prefix("=")
}

///|
async fn body_length(body : RequestBody) -> Int64? {
  match body {
    EmptyBody => None
    BytesBody(data) => Some(data.length().to_int64())
    FileBody(path) => {
      let file = @fs.open(path, mode=ReadOnly) catch {
        err =>
          raise transfer_error(
            InputFailure,
            "cannot open request body '\{path}': \{err}",
          )
      }
      defer file.close()
      Some(file.size()) catch {
        err =>
          raise transfer_error(
            InputFailure,
            "cannot determine request body size '\{path}': \{err}",
          )
      }
    }
    StdinBody => None
  }
}

///|
fn request_headers(
  headers : ArrayView[HttpHeader],
  length : Int64?,
  resume_from : Int64?,
) -> PreparedHeaders {
  let persistent : HeaderFields = { fields: [], }
  let per_request : HeaderFields = { fields: [], }
  for header in headers {
    if header.name.to_lower() == "user-agent" {
      persistent.set(header.name, header.value)
    } else {
      per_request.set(header.name, header.value)
    }
  }
  let authorization_supplied = per_request.contains("Authorization")
  if length is Some(value) && !per_request.contains("Content-Length") {
    per_request.set("Content-Length", value.to_string())
  }
  if !per_request.contains("Accept-Encoding") {
    // Keep transfer counts and Range offsets on the encoded representation.
    per_request.set("Accept-Encoding", "identity")
  }
  if resume_from is Some(value) && value > 0L && !per_request.contains("Range") {
    per_request.set("Range", "bytes=\{value}-")
  }
  { persistent, per_request, authorization_supplied, }
}
