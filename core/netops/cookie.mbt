///|
priv enum WgetCookieExpiry {
  Age(Double)
  Date(Int64)
}

///|
priv struct Cookie {
  name : String
  value : String
  path : String?
  domain : String?
  max_age : Int64?
  expires_raw : String?
  secure : Bool
  http_only : Bool
  wget_expiry : Array[WgetCookieExpiry]
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
  wget_expiry~ : Array[WgetCookieExpiry] = [],
) -> Cookie {
  {
    name,
    value,
    path,
    domain,
    max_age,
    expires_raw,
    secure,
    http_only,
    wget_expiry,
  }
}

///|
priv struct Response {
  code : Int32
  reason : String
  headers : Map[@http.CaseInsensitiveString, String]
  cookies : Array[Cookie]
}
