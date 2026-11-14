///|
/// Existing text corpora retain their original Unicode expectations. Adapt only
/// the input/output boundary to the byte-oriented implementation.
fn wire_cookie(text : String) -> Cookie? {
  parse_cookie_octets(cookie_text(@utf8.encode(text)))
}

///|
fn CookieJar::load_netscape(self : CookieJar, text : String) -> Unit {
  ignore(self.load_bytes(@utf8.encode(text)))
}

///|
fn CookieJar::load_netscape_at(
  self : CookieJar,
  text : String,
  now : Int64,
) -> Unit {
  ignore(self.load_octets_at(cookie_text(@utf8.encode(text)), now))
}

///|
fn CookieJar::header_for(
  self : CookieJar,
  url : ParsedUrl,
  now : Int64,
) -> String? {
  self.header_octets(url, now).map(cookie_utf8)
}

///|
fn CookieJar::netscape(
  self : CookieJar,
  include_session~ : Bool = true,
  now~ : Int64 = @fsops.current_timestamp().seconds,
) -> String {
  cookie_utf8(self.netscape_octets(include_session~, now~))
}

///|
fn Cookie::new(
  name : String,
  value : String,
  path? : String,
  domain? : String,
  max_age? : Int64,
  expires_raw? : String,
  secure~ : Bool = false,
  http_only~ : Bool = false,
) -> Cookie {
  {
    name: cookie_text(@utf8.encode(name)),
    value: cookie_text(@utf8.encode(value)),
    path: path.map(value => cookie_text(@utf8.encode(value))),
    domain: domain.map(value => cookie_text(@utf8.encode(value))),
    max_age,
    expires_raw,
    secure,
    http_only,
  }
}
