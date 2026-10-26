///|
/// Keep each pattern's capture numbering independent, then choose the earliest
/// start and longest span across the compiled expressions.
fn Matcher::next_match(
  self : Matcher,
  line : String,
  position : Int32,
) -> (Int32, Int32)? {
  if position > line.length() {
    return None
  }
  match self {
    ManyFixed(set) => set.find_span(@bytere.bytes(line), start=position)
    Fixed(patterns, whole, word) => {
      let bytes = Bytes::makei(line.length(), index => {
        line[index].to_int().to_byte()
      })
      fixed_span(patterns, bytes[:], position, whole, word)
    }
    Regular(patterns, whole, word) => {
      let mut best = None
      for pattern in patterns {
        if pattern.find_span(line, start=position, whole~, word~) is Some(hit) {
          match best {
            Some((start, end)) =>
              if hit.0 < start || (hit.0 == start && hit.1 > end) {
                best = Some(hit)
              }
            None => best = Some(hit)
          }
        }
      }
      best
    }
  }
}
