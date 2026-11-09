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
    name,
    value,
    path,
    domain,
    secure,
    wget_expiry: match max_age {
      Some(age) => [Age(age.to_double())]
      None => []
    },
  }
}
