///|
async fn partition_boundaries(source : String, marker : Bytes?) -> Array[Int64] {
  let result = [0L]
  guard marker is Some(prefix) else { return result }
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let buffer = FixedArray::make(65536, b'\x00')
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  let mut offset = 0L
  let mut start = 0L
  let mut matched = true
  let mut prefix_length = 0
  while input.read(buffer) is count && count > 0 {
    for byte in bytes[:count] {
      if byte == b'\n' {
        if matched && prefix_length == prefix.length() && start > 0L {
          result.push(start)
        }
        start = offset + 1L
        matched = true
        prefix_length = 0
      } else if prefix_length < prefix.length() {
        if byte != prefix[prefix_length] {
          matched = false
        }
        prefix_length += 1
      }
      offset += 1L
    }
  }
  if start < offset && matched && prefix_length == prefix.length() && start > 0L {
    result.push(start)
  }
  result
}

///|
async fn check_partition_source(
  root : String,
  source : String,
  marker : Bytes?,
) -> Array[String] {
  let errors : Array[String] = []
  let parts = @fs.readdir(root).filter(name => name.has_prefix("part-"))
  parts.sort_by((a, b) => {
    if natural_key_less(a, b) {
      -1
    } else if a == b {
      0
    } else {
      1
    }
  })
  let input = @fs.open(source, mode=ReadOnly)
  defer input.close()
  let total = input.size()
  let expected = partition_boundaries(source, marker)
  expected.push(total)
  if marker is None &&
    parts.length().to_int64() != (total + 1048575L) / 1048576L {
    errors.push("byte partition count differs from complete source length")
  }
  if marker is Some(_) && parts.length() != expected.length() - 1 {
    errors.push("partition count differs from source marker boundaries")
  }
  let mut offset = 0L
  for index, name in parts {
    let piece = @fs.open(root + "/" + name, mode=ReadOnly)
    let size = piece.size()
    if marker is Some(_) &&
      index + 1 < expected.length() &&
      size != expected[index + 1] - expected[index] {
      errors.push("fragment size differs from source boundary")
    }
    if marker is None && size != (total - offset).min(1048576L) {
      errors.push("byte fragment does not match declared1MiB split")
    }
    let mut position = 0L
    while position < size {
      let count = (size - position).min(65536L).to_int()
      if offset + count.to_int64() > total ||
        piece.read_exactly_at(count, position~) !=
        input.read_exactly_at(count, position=offset) {
        errors.push("fragment bytes differ from complete source range")
        break
      }
      position += count.to_int64()
      offset += count.to_int64()
    }
    piece.close()
  }
  if offset != total {
    errors.push("fragments do not cover complete source")
  }
  errors
}
