///|
fn Cookie::new(
  name : String,
  value : String,
  path? : String,
  domain? : String,
  max_age? : Int64,
  secure~ : Bool = false,
) -> Cookie {
  {
    name: cookie_text(@utf8.encode(name)),
    value: cookie_text(@utf8.encode(value)),
    path: path.map(value => cookie_text(@utf8.encode(value))),
    domain: domain.map(value => cookie_text(@utf8.encode(value))),
    secure,
    wget_expiry: match max_age {
      Some(age) => [Age(age.to_double())]
      None => []
    },
  }
}
