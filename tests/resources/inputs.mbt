///|
async fn write_input(
  path : String,
  size : Int64,
  record : Int64,
  mixed : Bool,
  binary : Bool,
  literal~ : String = "",
) -> Unit {
  let file = @fs.create(path)
  defer file.close()
  let seed = if record == size && !mixed {
    b"needle-alpha-beta-0123456789-"
  } else {
    b"needle alpha beta 0123456789 "
  }
  let widths = [7L, 89L, 4097L, 65537L, 128L]
  let places = [
    1000000000L, 100000000L, 10000000L, 1000000L, 100000L, 10000L, 1000L, 100L, 10L,
    1L,
  ]
  let mut position = 0L
  let mut row = 0L
  let mut rank = 12345L
  let mut column = 0L
  let mut width = if mixed { widths[0] } else { record }
  while position < size {
    let count = (size - position).min(65536).to_int()
    let bytes = Bytes::makei(count, index => {
      let at = position + index.to_int64()
      let end = column == width - 1 || at == size - 1
      let byte = if end {
        b'\n'
      } else if !literal.is_empty() {
        if literal == "literal-sparse" {
          b'Z'
        } else {
          b'a'
        }
      } else if binary && row % 3 == 1 && column == 13 {
        b'\x00'
      } else if binary && row % 3 == 1 && column == 31 {
        b'\xff'
      } else if column < 10 {
        ((rank / places[column.to_int()] % 10).to_int() + 48).to_byte()
      } else {
        seed[((column - 10) % seed.length().to_int64()).to_int()]
      }
      if end {
        row += 1
        rank = (row * 1103515245L + 12345L) % 1000000007L
        column = 0
        if mixed {
          width = widths[(row % widths.length().to_int64()).to_int()]
        }
      } else {
        column += 1
      }
      byte
    })
    file.write(bytes)
    position += count.to_int64()
  }
}

///|
#derive(ToJson)
struct ContentInput {
  bytes : Int64
  rows : Int64
  short_record_bytes : Int64
  mixed : Bool
  section_offsets : Array[Int64]
}

///|
fn content_width(row : Int64, mixed : Bool) -> Int64 {
  if !mixed {
    return 80L
  }
  let at = row % 259L
  if at < 256L {
    [32L, 64L, 96L, 128L][((at + row / 259L) % 4L).to_int()]
  } else if at < 258L {
    512L
  } else {
    4096L
  }
}

///|
fn content_row_offset(row : Int64, mixed : Bool) -> Int64 {
  if !mixed {
    return row * 80L
  }
  let first = row / 259L * 259L
  let mut offset = row / 259L * 25600L
  for index = first; index < row; index = index + 1L {
    offset += content_width(index, true)
  }
  offset
}

///|
// The content modes keep the requested byte budget while exercising many
// ordinary records. The mixed cycle assigns 80% of complete-cycle bytes to
// records of at most 128 bytes; it is a public ordered synthetic control.
async fn write_content_input(
  path : String,
  size : Int64,
  mixed : Bool,
  sections : Bool,
) -> ContentInput {
  let output = @fs.create(path)
  defer output.close()
  let places = [
    1000000000L, 100000000L, 10000000L, 1000000L, 100000L, 10000L, 1000L, 100L, 10L,
    1L,
  ]
  let alphabet = b"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-./:=\t"
  let boundaries : Array[Int64] = []
  let mut offset = 0L
  let mut row = 0L
  let mut column = 0L
  let mut width = content_width(0L, mixed)
  let mut short_bytes = 0L
  let mut marked = false
  while offset < size {
    let length = (size - offset).min(65536L).to_int()
    let bytes = Bytes::makei(length, index => {
      let at = offset + index.to_int64()
      if column == 0L {
        marked = sections && row % 4096L == 4095L && size - at >= 9L
        if marked {
          boundaries.push(at)
        }
      }
      let rank = (row * 1103515245L + 12345L) % 1000000007L
      let last = column == width - 1L || at == size - 1L
      let byte = if last {
        b'\n'
      } else if marked && column < 8L {
        b"SECTION "[column.to_int()]
      } else if column < 10L {
        ((rank / places[column.to_int()] % 10L).to_int() + 48).to_byte()
      } else {
        alphabet[((rank * 31L + column * 2654435761L + 104729L) %
        1000000007L %
        alphabet.length().to_int64()).to_int()]
      }
      if width <= 128L {
        short_bytes += 1L
      }
      if last {
        row += 1L
        column = 0L
        width = content_width(row, mixed)
      } else {
        column += 1L
      }
      byte
    })
    output.write(bytes)
    offset += length.to_int64()
  }
  {
    bytes: size,
    rows: row,
    short_record_bytes: short_bytes,
    mixed,
    section_offsets: boundaries,
  }
}
