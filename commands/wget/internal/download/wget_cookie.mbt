///|
const MaxWgetCookieHostLabels = 32

///|
fn wget_cookie_host_allowed(host : String) -> Bool {
  let mut labels = 1
  for character in host {
    if character == '.' {
      labels += 1
    }
  }
  labels <= MaxWgetCookieHostLabels
}

///|
fn wget_cookie_domain_port(value : String) -> (String, Int32?) {
  guard value.find(":") is Some(colon) else { return (value, None) }
  let mut port = 0
  for character in value[colon + 1:] {
    guard character >= '0' && character <= '9' else { return (value, None) }
    port = port * 10 + character.to_int() - 48
  }
  (value[:colon].to_owned(), if port == 0 { None } else { Some(port) })
}

///|
priv struct WgetCookieField {
  name : String
  value : String?
  primary : String
}

///|
fn wget_cookie_space(code : UInt16) -> Bool {
  code == 32 || (code >= 9 && code <= 13)
}

///|
fn wget_cookie_fields(text : String) -> Array[WgetCookieField]? {
  let fields : Array[WgetCookieField] = []
  let mut offset = 0
  while offset < text.length() {
    while offset < text.length() && wget_cookie_space(text[offset]) {
      offset += 1
    }
    if offset == text.length() {
      break
    }
    let name_start = offset
    while offset < text.length() &&
          !wget_cookie_space(text[offset]) &&
          text[offset] != 61 &&
          text[offset] != 59 {
      offset += 1
    }
    guard offset > name_start else { return None }
    let mut name = text[name_start:offset].to_owned()
    while offset < text.length() && wget_cookie_space(text[offset]) {
      offset += 1
    }
    if offset == text.length() || text[offset] == 59 {
      fields.push({ name, value: None, primary: "", })
      offset += 1
      continue
    }
    guard text[offset] == 61 else { return None }
    offset += 1
    while offset < text.length() && wget_cookie_space(text[offset]) {
      offset += 1
    }
    let quoted = offset < text.length() && text[offset] == 34
    if quoted {
      offset += 1
    }
    let mut start = offset
    let mut end = offset
    if quoted {
      while offset < text.length() && text[offset] != 34 {
        offset += 1
      }
      guard offset < text.length() else { return None }
      end = offset
      offset += 1
      // The pinned extractor skips text after the closing quote up to ';'.
      while offset < text.length() && text[offset] != 59 {
        offset += 1
      }
    } else {
      while offset < text.length() && text[offset] != 59 {
        offset += 1
      }
      end = offset
      while end > start && wget_cookie_space(text[end - 1]) {
        end -= 1
      }
    }
    if offset < text.length() {
      offset += 1
    }
    // Wget applies its RFC 2231 parameter-name adjustment to cookies too.
    if name.find("*") is Some(star) {
      let encoded = name.has_suffix("*") || name[star + 1:].contains("*")
      name = name[:star].to_owned()
      if encoded && text[start:end].rev_find("'") is Some(apostrophe) {
        start += apostrophe + 1
      }
    }
    let value = text[start:end].to_owned()
    let primary_start = if start > 0 && text[start - 1] == 34 {
      start - 1
    } else {
      start
    }
    let primary_end = if end < text.length() && text[end] == 34 {
      end + 1
    } else {
      end
    }
    fields.push({
      name,
      value: Some(value),
      primary: text[primary_start:primary_end].to_owned(),
    })
  }
  Some(fields)
}

///|
fn wire_cookie(text : String) -> Cookie? {
  guard wget_cookie_fields(text) is Some(fields) &&
    fields.get(0) is Some(first) &&
    first.value is Some(_) else {
    return None
  }
  let mut path = None
  let mut domain = None
  let expiry : Array[WgetCookieExpiry] = []
  let mut secure = false
  for field in fields[1:] {
    match cookie_ascii_lower(field.name) {
      "domain" => {
        guard field.value is Some(value) && value != "" else { return None }
        domain = Some(value)
      }
      "path" => {
        guard field.value is Some(value) && value != "" else { return None }
        path = Some(value)
      }
      "expires" => {
        guard field.value is Some(value) &&
          value != "" &&
          @utf8.encode(value).length() < 128 else {
          return None
        }
        if wget_cookie_date(value) is Some(date) {
          expiry.push(Date(date))
        }
      }
      "max-age" => {
        guard field.value is Some(value) &&
          value != "" &&
          @utf8.encode(value).length() < 32 else {
          return None
        }
        guard wget_cookie_number(value) is Some(age) && age != -1.0 else {
          return None
        }
        expiry.push(Age(age))
      }
      "secure" => secure = true
      _ => ()
    }
  }
  Some({
    name: first.name,
    value: first.primary,
    path,
    domain,
    wget_expiry: expiry,
    secure,
  })
}
