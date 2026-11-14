///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Flatten array to specified depth
fn flatten_array_into(
  arr : Array[Json],
  depth : Int32,
  out : Array[Json],
) -> Unit {
  guard depth > 0 else {
    for elem in arr {
      out.push(elem)
    }
    return
  }
  for elem in arr {
    match elem {
      Array(inner) => flatten_array_into(inner, depth - 1, out)
      _ => out.push(elem)
    }
  }
}

///|
fn flatten_array(arr : Array[Json], depth : Int32) -> Array[Json] {
  guard depth > 0 else { return arr }
  let result : Array[Json] = []
  flatten_array_into(arr, depth, result)
  result
}

///|
/// Recursive descent: yield input and all nested values
fn recurse_all(input : Json) -> Iter[Json] {
  match input {
    Array(arr) =>
      Iter::singleton(input).concat(arr.iter().flat_map(recurse_all))
    Object(obj) =>
      Iter::singleton(input).concat(obj.values().flat_map(recurse_all))
    _ => Iter::singleton(input)
  }
}
