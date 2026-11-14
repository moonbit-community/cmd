///|
fn cookie_utf8(text : String) -> String {
  @utf8.decode(cookie_bytes(text)) catch {
    _ => text
  }
}

///|
fn wget_cookie_domain_allows(host : String, domain : String) -> Bool {
  wget_cookie_domain_allows_octets(
    cookie_text(@utf8.encode(host)),
    cookie_text(@utf8.encode(domain)),
  )
}

///|
/// The retained text corpora enter and leave the parser through UTF-8; their
/// expected values remain independent of the byte-oriented storage.
fn wire_cookie(text : String) -> Cookie? {
  parse_cookie_octets(cookie_text(@utf8.encode(text)))
}

///|
fn CookieJar::load_netscape(self : CookieJar, text : String) -> Unit {
  self.load_bytes(@utf8.encode(text))
}

///|
fn CookieJar::load_netscape_at(
  self : CookieJar,
  text : String,
  now : Int64,
) -> Unit {
  self.load_octets_at(cookie_text(@utf8.encode(text)), now)
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
