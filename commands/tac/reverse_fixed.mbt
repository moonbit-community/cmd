///|
// KMP carries only the unmatched separator prefix across backward reads.
// Completed matches are nonoverlapping, so at most ceil(block/separator)
// starts are retained. Clearing the array reuses its bounded allocation.
fn reverse_block_matches(
  data : BytesView,
  separator : Bytes,
  failure : FixedArray[Int32],
  carried : Ref[Int32],
  starts : Array[Int32],
) -> Unit {
  starts.clear()
  let mut matched = carried.val
  let first = separator[separator.length() - 1:]
  let mut index = data.length() - 1
  while index >= 0 {
    // In the zero-prefix state only the final separator byte can start a
    // reversed match. Skip other bytes without changing any KMP state.
    if matched == 0 && index >= 32 && data[index] != first[0] {
      guard data[:index].rev_find(first) is Some(next) else { break }
      index = next
    }
    let byte = data[index]
    while matched > 0 && byte != separator[separator.length() - matched - 1] {
      matched = failure[matched - 1]
    }
    if byte == separator[separator.length() - matched - 1] {
      matched += 1
    }
    if matched == separator.length() {
      starts.push(index)
      matched = 0
    }
    index -= 1
  }
  carried.val = matched
}

///|
fn reverse_matched_ranges(
  data : BytesView,
  starts : Array[Int32],
  first : Int32,
  offset : Int32,
  end : Int32,
  output : @buffer.Buffer,
) -> Int32 {
  let mut end = end
  for index in first..<starts.length() {
    let boundary = starts[index] + offset
    output.write_bytes(data[boundary:end])
    end = boundary
  }
  end
}
