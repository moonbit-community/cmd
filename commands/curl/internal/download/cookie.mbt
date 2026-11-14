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
}

///|
priv struct Response {
  code : Int32
  reason : String
  headers : Map[@http.CaseInsensitiveString, String]
}
