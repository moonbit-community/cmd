///|
priv struct Snapshot {
  data : @fs.File
  index : @fs.File
  size : Int64
  records : Int64
  mut page_start : Int64
  mut page : Bytes
  mut data_start : Int64
  mut data_page : Bytes
}

///|
// Strategy: csplit-page-processing

///|
priv struct IndexPage {
  bytes : FixedArray[Byte]
  mut used : Int32
  mut entries : Int64
}

///|
fn IndexPage::push(self : IndexPage, position : Int64) -> Unit raise {
  guard self.entries < 1152921504606846975L else {
    fail("line index exceeds signed 64-bit file offsets")
  }
  for byte in 0..<8 {
    self.bytes[self.used + byte] = ((position >> (byte * 8)) & 255L).to_byte()
  }
  self.used += 8
  self.entries += 1
}

///|
async fn IndexPage::flush(self : IndexPage, writer : &@io.Writer) -> Unit {
  let count = self.used
  self.used = 0
  if count > 0 {
    writer.write(self.bytes.unsafe_reinterpret_as_bytes()[:count])
  }
}

///|
async fn snapshot(
  reader : &@io.Reader,
  data : @fs.File,
  index : @fs.File,
) -> Snapshot {
  let offsets : IndexPage = {
    bytes: FixedArray::make(65536, b'\x00'),
    used: 0,
    entries: 0L,
  }
  offsets.push(0)
  let mut size = 0L
  let mut last = 0L
  while reader.read_some(max_len=65536) is Some(bytes) {
    guard size <= 9223372036854775807L - bytes.length().to_int64() else {
      fail("input exceeds signed 64-bit file offsets")
    }
    data.write(bytes)
    for position in 0..<bytes.length() {
      if bytes[position] == b'\n' {
        last = size + position.to_int64() + 1
        // Encode boundaries synchronously; only full pages cross the I/O
        // boundary. Input data still reaches the spool before its index.
        if offsets.used == offsets.bytes.length() {
          offsets.flush(index)
        }
        offsets.push(last)
      }
    }
    size += bytes.length().to_int64()
  }
  if last != size {
    if offsets.used == offsets.bytes.length() {
      offsets.flush(index)
    }
    offsets.push(size)
  }
  offsets.flush(index)
  {
    data,
    index,
    size,
    records: offsets.entries - 1,
    page_start: -1,
    page: b"",
    data_start: -1,
    data_page: b"",
  }
}

///|
async fn Snapshot::offset(self : Snapshot, line : Int64) -> Int64 {
  let first = line / 8192 * 8192
  if first != self.page_start {
    let count = (self.records + 1 - first).min(8192).to_int()
    self.page = self.index.read_exactly_at(count * 8, position=first * 8)
    self.page_start = first
  }
  let start = (line - first).to_int() * 8
  let mut result = 0L
  for byte in 0..<8 {
    result = result | (self.page[start + byte].to_int64() << (byte * 8))
  }
  result
}

///|
fn Snapshot::cached_offset(self : Snapshot, line : Int64) -> Int64? {
  let relative = line - self.page_start
  if self.page_start < 0 ||
    relative < 0 ||
    relative >= (self.page.length() / 8).to_int64() {
    return None
  }
  let start = relative.to_int() * 8
  let mut result = 0L
  for byte in 0..<8 {
    result = result | (self.page[start + byte].to_int64() << (byte * 8))
  }
  Some(result)
}

///|
// Only records fully owned by both existing caches are eligible. No read,
// cursor advance or borrowed view survives this synchronous call.
fn Snapshot::matches_cached(
  self : Snapshot,
  line : Int64,
  matcher : @bytere.RecordMatcher,
) -> Bool? {
  guard self.cached_offset(line) is Some(start) &&
    self.cached_offset(line + 1) is Some(end) else {
    return None
  }
  guard self.data_start >= 0 &&
    start >= self.data_start &&
    end <= self.data_start + self.data_page.length().to_int64() else {
    return None
  }
  let begin = (start - self.data_start).to_int()
  let mut stop = (end - self.data_start).to_int()
  if stop > begin && self.data_page[stop - 1] == b'\n' {
    stop -= 1
  }
  Some(matcher.matches(self.data_page[begin:stop]))
}

///|
// Stay synchronous while both caches own every record. The caller resumes
// the original refill path at the first ineligible record.
fn Snapshot::search_cached(
  self : Snapshot,
  first : Int64,
  matcher : @bytere.RecordMatcher,
) -> (Int64, Bool) {
  let mut line = first
  while line < self.records {
    match self.matches_cached(line, matcher) {
      Some(true) => return (line, true)
      Some(false) => line += 1
      None => break
    }
  }
  (line, false)
}

///|
async fn Snapshot::matches(
  self : Snapshot,
  line : Int64,
  pattern : @bytere.Pattern,
) -> Bool {
  let start = self.offset(line)
  let length = self.offset(line + 1) - start
  guard length <= 2147483647L else {
    fail("regular-expression line exceeds the supported record length")
  }
  let text = StringBuilder()
  let end = start + length
  let mut position = start
  while position < end {
    let first = position / 65536 * 65536
    if first != self.data_start {
      self.data_page = self.data.read_exactly_at(
        (self.size - first).min(65536).to_int(),
        position=first,
      )
      self.data_start = first
    }
    let begin = (position - first).to_int()
    let take = (end - position)
      .min((self.data_page.length() - begin).to_int64())
      .to_int()
    for byte in begin..<(begin + take) {
      if position + (byte - begin).to_int64() + 1 < end ||
        self.data_page[byte] != b'\n' {
        text.write_char(self.data_page[byte].to_int().unsafe_to_char())
      }
    }
    position += take.to_int64()
  }
  pattern.is_match(text.to_string())
}

///|
async fn Snapshot::copy(
  self : Snapshot,
  first : Int64,
  end : Int64,
  writer : &@io.Writer,
) -> Unit {
  let mut position = first
  while position < end {
    let length = (end - position).min(65536).to_int()
    let bytes = self.data.read_exactly_at(length, position~)
    writer.write(bytes)
    position += length.to_int64()
  }
}
