///|
// Strategy: patch-byte-records

///|
priv struct RawLine {
  value : BytesView
  terminated : Bool
} derive(Eq)

///|
fn raw_lines(data : Bytes) -> Array[RawLine] {
  let result : Array[RawLine] = []
  let mut start = 0
  while data[start:].find(b"\n") is Some(relative) {
    let end = start + relative
    result.push({ value: data[start:end], terminated: true, })
    start = end + 1
  }
  if start < data.length() {
    result.push({ value: data[start:], terminated: false, })
  }
  result
}
