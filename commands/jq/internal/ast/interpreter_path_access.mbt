///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
fn get_at_path(current : Json, path : ArrayView[Json]) -> Json? {
  match path {
    [] => Some(current)
    [segment, .. rest] =>
      match (current, segment) {
        (Object(obj), String(key)) =>
          match obj.get(key) {
            Some(v) => get_at_path(v, rest)
            None => None
          }
        (Array(arr), Number(idx, ..)) => {
          // Negative indices count from the end, as in `.[-1]`.
          let i = normalize_index(idx.to_int(), arr.length())
          if i >= 0 && i < arr.length() {
            get_at_path(arr[i], rest)
          } else {
            None
          }
        }
        _ => None
      }
  }
}
