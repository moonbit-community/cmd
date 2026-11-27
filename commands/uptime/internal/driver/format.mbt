///|
fn pretty(seconds : Double) -> String {
  let mut remaining = seconds
  let parts = []
  for
    (unit, size) in [
      ("decade", 315360000),
      ("year", 31536000),
      ("week", 604800),
      ("day", 86400),
      ("hour", 3600),
      ("minute", 60),
    ] {
    if remaining > size.to_double() {
      let count = (remaining / size.to_double()).to_int()
      remaining -= count.to_double() * size.to_double()
      parts.push(
        count.to_string() + " " + unit + (if count == 1 { "" } else { "s" }),
      )
    } else if unit == "minute" && remaining < 60.0 {
      parts.push("0 minutes")
    }
  }
  "up " + parts.join(", ")
}
