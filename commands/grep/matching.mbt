///|
fn match_boundaries(
  line : String,
  start : Int32,
  end : Int32,
  whole : Bool,
  word : Bool,
) -> Bool {
  (!whole || (start == 0 && end == line.length())) &&
  (
    !word ||
    (
      (start == 0 || !is_word_char(line[start - 1].to_int().unsafe_to_char())) &&
      (
        end == line.length() ||
        !is_word_char(line[end].to_int().unsafe_to_char())
      )
    )
  )
}

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
    Fixed(patterns, whole, word) => {
      for start in position..<=line.length() {
        let mut longest = -1
        for pattern in patterns {
          let end = start + pattern.length()
          if end <= line.length() &&
            line[start:end] == pattern &&
            match_boundaries(line, start, end, whole, word) &&
            end > longest {
            longest = end
          }
        }
        if longest >= 0 {
          return Some((start, longest))
        }
      }
      None
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
