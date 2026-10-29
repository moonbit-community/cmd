///|
// Strategy: tac-spool
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
  if separator.length() == 1 {
    reverse_byte_file(file, separator, before, writer, size)
    return
  }
  let length = file.size()
  let writer = @io.BufferedWriter::new(writer, size=block_size)
  let scan = FixedArray::make(size, b'\x00')
  let output = FixedArray::make(size, b'\x00')
  let batch = @buffer.Buffer(size_hint=size)
  let matches : Array[Int32] = []
  let failure = reverse_failure(separator)
  let mut past_end = length
  let mut block_end = length
  let matched = Ref(0)
  while block_end > 0 {
    let block_start = (block_end - size.to_int64()).max(0L)
    let count = (block_end - block_start).to_int()
    if file.read_at(scan, position=block_start, len=count) != count {
      raise @io.ReaderClosed
    }
    let data = scan.unsafe_reinterpret_as_bytes()[:count]
    reverse_block_matches(data, separator, failure, matched, matches)
    let offset = if before { 0 } else { separator.length() }
    let mut index = 0
    // A separator can end beyond this block. Keep copying spanning ranges
    // until both endpoints are local; only then is the scan buffer sufficient.
    while index < matches.length() && past_end > block_end {
      let boundary = block_start + (matches[index] + offset).to_int64()
      @tempio.copy_range(file, boundary, past_end, output, writer)
      past_end = boundary
      index += 1
    }
    if index < matches.length() {
      past_end = block_start +
        reverse_matched_ranges(
          data,
          matches,
          index,
          offset,
          (past_end - block_start).to_int(),
          batch,
        ).to_int64()
      if !batch.is_empty() {
        let bytes = batch.to_bytes()
        batch.reset()
        writer.write(bytes)
      }
    }
    block_end = block_start
  }
  @tempio.copy_range(file, 0L, past_end, output, writer)
  writer.flush()
}

///|
// The first boundary in a block may complete a range from a later block.
// Every remaining range is local: copy those synchronously, then write once.
fn reverse_byte_ranges(
  data : BytesView,
  separator : Bytes,
  before : Bool,
  last : Int32,
  output : @buffer.Buffer,
) -> Int32 {
  let mut search_end = last
  let mut end = last + (if before { 0 } else { 1 })
  while data[:search_end].rev_find(separator) is Some(index) {
    let boundary = index + (if before { 0 } else { 1 })
    output.write_bytes(data[boundary:end])
    end = boundary
    search_end = index
  }
  end
}

///|
async fn reverse_byte_file(
  file : @fs.File,
  separator : Bytes,
  before : Bool,
  writer : &@io.Writer,
  size : Int32,
) -> Unit {
  let length = file.size()
  let writer = @io.BufferedWriter::new(writer, size=block_size)
  let scan = FixedArray::make(size, b'\x00')
  let range = FixedArray::make(size, b'\x00')
  let batch = @buffer.Buffer(size_hint=size)
  let mut past_end = length
  let mut block_end = length
  let mut first = true
  while block_end > 0 {
    let block_start = (block_end - size.to_int64()).max(0L)
    let count = (block_end - block_start).to_int()
    if file.read_at(scan, position=block_start, len=count) != count {
      raise @io.ReaderClosed
    }
    let data = scan.unsafe_reinterpret_as_bytes()[:count]
    if data.rev_find(separator) is Some(last) {
      let boundary = block_start +
        (last + (if before { 0 } else { 1 })).to_int64()
      if before || !first || boundary != past_end {
        if past_end <= block_end {
          writer.write(
            data[(boundary - block_start).to_int():(past_end - block_start).to_int()],
          )
        } else {
          @tempio.copy_range(file, boundary, past_end, range, writer)
        }
      }
      past_end = block_start +
        reverse_byte_ranges(data, separator, before, last, batch).to_int64()
      first = false
      if !batch.is_empty() {
        let bytes = batch.to_bytes()
        batch.reset()
        writer.write(bytes)
      }
    }
    block_end = block_start
  }
  @tempio.copy_range(file, 0L, past_end, range, writer)
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
      @tempio.copy_range(
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
  @tempio.copy_range(file, 0L, past_end.to_int64(), output, writer)
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
  let directory = @tempio.Directory::new(prefix="cli-tac-")
  with_spool_cleanup(
    () => {
      let file = @fs.open(
        directory.path() + "/input",
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
    },
    () => directory.close(),
  )
}

///|
// The operation owns its file handles and closes them before directory cleanup.
// A cleanup-only failure is observable; a primary failure keeps its diagnostic.
async fn with_spool_cleanup(
  operation : async () -> Unit,
  cleanup : async () -> Unit,
) -> Unit {
  {
    errdefer (cleanup() catch { _ => () })
    operation()
  }
  cleanup()
}
