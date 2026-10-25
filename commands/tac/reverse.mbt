///|
let block_size : Int32 = 65536

///|
// Some regular pseudo files report zero or a page-sized nominal length. Probe
// before output begins; an unknown extent must be consumed as a stream.
async fn has_extent(file : @fs.File, length : Int64) -> Bool {
  let probe = FixedArray::make(1, b'\x00')
  if length == 0 {
    file.read_at(probe, position=0L) == 0
  } else {
    file.read_at(probe, position=length - 1L) == 1
  }
}

///|
async fn write_range(
  file : @fs.File,
  start : Int64,
  end : Int64,
  buffer : FixedArray[Byte],
  writer : &@io.Writer,
) -> Unit {
  let mut position = start
  while position < end {
    let length = (end - position).min(buffer.length().to_int64()).to_int()
    let count = file.read_at(buffer, position~, len=length)
    if count != length {
      raise @io.ReaderClosed
    }
    writer.write(buffer.unsafe_reinterpret_as_bytes()[:count])
    position += count.to_int64()
  }
}

///|
/// KMP in the direction of traversal avoids rescanning long shared separator
/// prefixes and carries matches across backward block boundaries.
fn reverse_failure(separator : Bytes) -> FixedArray[Int32] {
  let failure = FixedArray::make(separator.length(), 0)
  let mut matched = 0
  for index in 1..<separator.length() {
    let byte = separator[separator.length() - index - 1]
    while matched > 0 && byte != separator[separator.length() - matched - 1] {
      matched = failure[matched - 1]
    }
    if byte == separator[separator.length() - matched - 1] {
      matched += 1
    }
    failure[index] = matched
  }
  failure
}

///|
async fn reverse_file(
  file : @fs.File,
  separator : Bytes,
  before : Bool,
  writer~ : &@io.Writer = @stdio.stdout,
  size~ : Int32 = block_size,
) -> Unit {
  let length = file.size()
  let writer = @io.BufferedWriter::new(writer, size=block_size)
  let scan = FixedArray::make(size, b'\x00')
  let output = FixedArray::make(size, b'\x00')
  let failure = reverse_failure(separator)
  let mut past_end = length
  let mut block_end = length
  let mut matched = 0
  let mut first = true
  while block_end > 0 {
    let block_start = (block_end - size.to_int64()).max(0L)
    let count = (block_end - block_start).to_int()
    if file.read_at(scan, position=block_start, len=count) != count {
      raise @io.ReaderClosed
    }
    for index = count - 1; index >= 0; index = index - 1 {
      let byte = scan[index]
      while matched > 0 && byte != separator[separator.length() - matched - 1] {
        matched = failure[matched - 1]
      }
      if byte == separator[separator.length() - matched - 1] {
        matched += 1
      }
      if matched == separator.length() {
        let start = block_start + index.to_int64()
        let boundary = if before { start } else { start + matched.to_int64() }
        if before || !first || boundary != past_end {
          if boundary >= block_start && past_end <= block_end {
            writer.write(
              scan.unsafe_reinterpret_as_bytes()[(boundary - block_start).to_int():(past_end -
              block_start).to_int()],
            )
          } else {
            write_range(file, boundary, past_end, output, writer)
          }
        }
        past_end = boundary
        matched = 0
        first = false
      }
    }
    block_end = block_start
  }
  write_range(file, 0L, past_end, output, writer)
  writer.flush()
}

///|
async fn reverse_regex(
  file : @fs.File,
  pattern : @bytere.Pattern,
  before : Bool,
  writer : &@io.Writer,
) -> Unit {
  // The matcher takes a contiguous byte-view String. Keep its O(input) cost
  // explicit; ranges are emitted from the immutable spool without an output copy.
  let text = @bytere.text(file.read_all().binary())
  let writer = @io.BufferedWriter::new(writer, size=block_size)
  let output = FixedArray::make(block_size, b'\x00')
  let mut search_end = text.length()
  let mut past_end = search_end
  let mut first = true
  while search_end > 0 {
    guard pattern.rfind_span(text, search_end) is Some((start, end)) else {
      break
    }
    let boundary = if before { start } else { end }
    if before || !first || boundary != past_end {
      write_range(
        file,
        boundary.to_int64(),
        past_end.to_int64(),
        output,
        writer,
      )
    }
    past_end = boundary
    search_end = start
    first = false
  }
  write_range(file, 0L, past_end.to_int64(), output, writer)
  writer.flush()
}

///|
async fn reverse_spooled(
  reader : &@io.Reader,
  separator : Bytes,
  before : Bool,
  regex~ : @bytere.Pattern? = None,
  writer~ : &@io.Writer = @stdio.stdout,
) -> Unit {
  let root = @fs.tmpdir(prefix="cli-tac-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fs.open(
    root + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  let buffer = FixedArray::make(block_size, b'\x00')
  while reader.read(buffer) is count && count > 0 {
    file.write(buffer.unsafe_reinterpret_as_bytes()[:count])
  }
  match regex {
    None => reverse_file(file, separator, before, writer~)
    Some(pattern) => reverse_regex(file, pattern, before, writer)
  }
}
