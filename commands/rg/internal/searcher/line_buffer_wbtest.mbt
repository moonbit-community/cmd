///|
let lb_sherlock : String = "For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached."

///|
struct LineBufferBuilder {
  mut capacity : Int32
  mut binary : BinaryMode
  mut alloc : BufferAllocation
}

///|
fn LineBufferBuilder::new() -> LineBufferBuilder {
  { capacity: DEFAULT_BUFFER_CAPACITY, binary: BNone, alloc: Eager, }
}

///|
fn LineBufferBuilder::capacity(
  self : LineBufferBuilder,
  n : Int32,
) -> LineBufferBuilder {
  self.capacity = n
  self
}

///|
fn LineBufferBuilder::binary_detection(
  self : LineBufferBuilder,
  b : BinaryMode,
) -> LineBufferBuilder {
  self.binary = b
  self
}

///|
fn LineBufferBuilder::buffer_alloc(
  self : LineBufferBuilder,
  a : BufferAllocation,
) -> LineBufferBuilder {
  self.alloc = a
  self
}

///|
fn LineBufferBuilder::build(self : LineBufferBuilder) -> LineBuffer {
  LineBuffer::new(self.capacity, b'\n', self.alloc, self.binary)
}

///|
struct LineBufferReader {
  rdr : &Reader
  lb : LineBuffer
}

///|
fn LineBufferReader::new(text : String, lb : LineBuffer) -> LineBufferReader {
  lb.clear()
  { rdr: SliceReader::from_bytes(@utf8.encode(text)), lb, }
}

///|
async fn LineBufferReader::fill(self : LineBufferReader) -> Bool {
  self.lb.fill(self.rdr) catch {
    e => abort(e.to_string())
  }
}

///|
async fn LineBufferReader::fill_is_err(self : LineBufferReader) -> Bool {
  try self.lb.fill(self.rdr) catch {
    _ => true
  } noraise {
    _ => false
  }
}

///|
fn LineBufferReader::buffer_is_empty(self : LineBufferReader) -> Bool {
  self.lb.buffer_len() == 0
}

///|
fn LineBufferReader::bstr(self : LineBufferReader) -> String {
  @utf8.decode_lossy(
    Bytes::from_array(self.lb.buf[self.lb.pos:self.lb.last_lineterm]),
  )
}

///|
fn LineBufferReader::consume(self : LineBufferReader, n : Int32) -> Unit {
  self.lb.consume(n)
}

///|
fn LineBufferReader::consume_all(self : LineBufferReader) -> Unit {
  self.lb.consume(self.lb.buffer_len())
}

///|
fn LineBufferReader::absolute_byte_offset(self : LineBufferReader) -> Int32 {
  self.lb.absolute_byte_offset.to_int()
}

///|
fn LineBufferReader::binary_byte_offset(self : LineBufferReader) -> Int32? {
  self.lb.binary_byte_offset.map(x => x.to_int())
}

///|
fn blen(s : String) -> Int32 {
  @utf8.encode(s).length()
}

///|
fn replace_str(
  slice : String,
  src : Byte,
  replacement : Byte,
) -> (String, Int32?) {
  let dst = @utf8.encode(slice).to_fixedarray()
  let result = replace_bytes(dst, 0, dst.length(), src, replacement)
  (@utf8.decode_lossy(Bytes::from_array(dst[:])), result)
}

///|
test "line_buffer/replace" {
  assert_eq(replace_str("", b'b', b'z'), ("", None))
  assert_eq(replace_str("a", b'a', b'a'), ("a", None))
  assert_eq(replace_str("a", b'b', b'z'), ("a", None))
  assert_eq(replace_str("abc", b'b', b'z'), ("azc", Some(1)))
  assert_eq(replace_str("abb", b'b', b'z'), ("azz", Some(1)))
  assert_eq(replace_str("aba", b'a', b'z'), ("zbz", Some(0)))
  assert_eq(replace_str("bbb", b'b', b'z'), ("zzz", Some(0)))
  assert_eq(replace_str("bac", b'b', b'z'), ("zac", Some(0)))
}

///|
async test "line_buffer/buffer_basics1" {
  let bytes = "homer\nlisa\nmaggie"
  let linebuf = LineBufferBuilder::new().build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nlisa\n")
  assert_eq(rdr.absolute_byte_offset(), 0)
  rdr.consume(5)
  assert_eq(rdr.absolute_byte_offset(), 5)
  rdr.consume_all()
  assert_eq(rdr.absolute_byte_offset(), 11)

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "maggie")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_basics2" {
  let bytes = "homer\nlisa\nmaggie\n"
  let linebuf = LineBufferBuilder::new().build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nlisa\nmaggie\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_basics3" {
  let bytes = "\n"
  let linebuf = LineBufferBuilder::new().build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_basics4" {
  let bytes = "\n\n"
  let linebuf = LineBufferBuilder::new().build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "\n\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_empty" {
  let bytes = ""
  let linebuf = LineBufferBuilder::new().build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_zero_capacity" {
  let bytes = "homer\nlisa\nmaggie"
  let linebuf = LineBufferBuilder::new().capacity(0).build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  while rdr.fill() {
    rdr.consume_all()
  }
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_small_capacity" {
  let bytes = "homer\nlisa\nmaggie"
  let linebuf = LineBufferBuilder::new().capacity(1).build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  let got = StringBuilder()
  while rdr.fill() {
    got.write_string(rdr.bstr())
    rdr.consume_all()
  }
  assert_eq(bytes, got.to_string())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_limited_capacity1" {
  let bytes = "homer\nlisa\nmaggie"
  let linebuf = LineBufferBuilder::new()
    .capacity(1)
    .buffer_alloc(ErrorLimit(5))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\n")
  rdr.consume_all()

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "lisa\n")
  rdr.consume_all()

  // This returns an error because while we have just enough room to
  // store maggie in the buffer, we *don't* have enough room to read one
  // more byte, so we don't know whether we're at EOF or not, and
  // therefore must give up.
  assert_true(rdr.fill_is_err())

  // We can mush on though!
  assert_eq(rdr.bstr(), "m")
  rdr.consume_all()

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "aggie")
  rdr.consume_all()

  assert_true(!rdr.fill())
}

///|
async test "line_buffer/buffer_limited_capacity2" {
  let bytes = "homer\nlisa\nmaggie"
  let linebuf = LineBufferBuilder::new()
    .capacity(1)
    .buffer_alloc(ErrorLimit(6))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\n")
  rdr.consume_all()

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "lisa\n")
  rdr.consume_all()

  // We have just enough space.
  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "maggie")
  rdr.consume_all()

  assert_true(!rdr.fill())
}

///|
async test "line_buffer/buffer_limited_capacity3" {
  let bytes = "homer\nlisa\nmaggie"
  let linebuf = LineBufferBuilder::new()
    .capacity(1)
    .buffer_alloc(ErrorLimit(0))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.fill_is_err())
  assert_eq(rdr.bstr(), "")
}

///|
async test "line_buffer/buffer_binary_none" {
  let bytes = "homer\nli\u{0}sa\nmaggie\n"
  let linebuf = LineBufferBuilder::new().build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nli\u{0}sa\nmaggie\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), None)
}

///|
async test "line_buffer/buffer_binary_quit1" {
  let bytes = "homer\nli\u{0}sa\nmaggie\n"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BQuit(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nli")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), 8)
  assert_eq(rdr.binary_byte_offset(), Some(8))
}

///|
async test "line_buffer/buffer_binary_quit2" {
  let bytes = "\u{0}homer\nlisa\nmaggie\n"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BQuit(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(!rdr.fill())
  assert_eq(rdr.bstr(), "")
  assert_eq(rdr.absolute_byte_offset(), 0)
  assert_eq(rdr.binary_byte_offset(), Some(0))
}

///|
async test "line_buffer/buffer_binary_quit3" {
  let bytes = "homer\nlisa\nmaggie\n\u{0}"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BQuit(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nlisa\nmaggie\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes) - 1)
  assert_eq(rdr.binary_byte_offset(), Some(blen(bytes) - 1))
}

///|
async test "line_buffer/buffer_binary_quit4" {
  let bytes = "homer\nlisa\nmaggie\u{0}\n"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BQuit(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nlisa\nmaggie")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes) - 2)
  assert_eq(rdr.binary_byte_offset(), Some(blen(bytes) - 2))
}

///|
async test "line_buffer/buffer_binary_quit5" {
  let linebuf = LineBufferBuilder::new().binary_detection(BQuit(b'u')).build()
  let rdr = LineBufferReader::new(lb_sherlock, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(
    rdr.bstr(),
    "For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, s",
  )
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), 76)
  assert_eq(rdr.binary_byte_offset(), Some(76))
  assert_eq(@utf8.encode(lb_sherlock)[76], b'u')
}

///|
async test "line_buffer/buffer_binary_convert1" {
  let bytes = "homer\nli\u{0}sa\nmaggie\n"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BConvert(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nli\nsa\nmaggie\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), Some(8))
}

///|
async test "line_buffer/buffer_binary_convert2" {
  let bytes = "\u{0}homer\nlisa\nmaggie\n"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BConvert(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "\nhomer\nlisa\nmaggie\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), Some(0))
}

///|
async test "line_buffer/buffer_binary_convert3" {
  let bytes = "homer\nlisa\nmaggie\n\u{0}"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BConvert(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nlisa\nmaggie\n\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), Some(blen(bytes) - 1))
}

///|
async test "line_buffer/buffer_binary_convert4" {
  let bytes = "homer\nlisa\nmaggie\u{0}\n"
  let linebuf = LineBufferBuilder::new()
    .binary_detection(BConvert(b'\x00'))
    .build()
  let rdr = LineBufferReader::new(bytes, linebuf)

  assert_true(rdr.buffer_is_empty())

  assert_true(rdr.fill())
  assert_eq(rdr.bstr(), "homer\nlisa\nmaggie\n\n")
  rdr.consume_all()

  assert_true(!rdr.fill())
  assert_eq(rdr.absolute_byte_offset(), blen(bytes))
  assert_eq(rdr.binary_byte_offset(), Some(blen(bytes) - 2))
}
