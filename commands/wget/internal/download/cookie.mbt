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
  secure : Bool
  wget_expiry : Array[WgetCookieExpiry]
}

///|
priv struct Response {
  code : Int32
  reason : String
  headers : Map[@http.CaseInsensitiveString, String]
  cookies : Array[Cookie]
}
