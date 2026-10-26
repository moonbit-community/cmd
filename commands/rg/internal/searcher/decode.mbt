///|
/// The decoder family of an encoding.
priv enum EncKind {
  Utf8
  Utf16LE
  Utf16BE
  /// A single-byte encoding, indexing `single_byte_names`.
  SingleByte(Int32)
  Gbk
  Gb18030
  Big5
  EucJp
  Iso2022Jp
  ShiftJis
  EucKr
  XUserDefined
} derive(Eq)

///|
/// The canonical WHATWG name of the encoding.
fn EncKind::name(self : EncKind) -> String {
  match self {
    Utf8 => "UTF-8"
    Utf16LE => "UTF-16LE"
    Utf16BE => "UTF-16BE"
    SingleByte(i) => single_byte_names[i]
    Gbk => "GBK"
    Gb18030 => "gb18030"
    Big5 => "Big5"
    EucJp => "EUC-JP"
    Iso2022Jp => "ISO-2022-JP"
    ShiftJis => "Shift_JIS"
    EucKr => "EUC-KR"
    XUserDefined => "x-user-defined"
  }
}

///|
/// A character encoding used to transcode input to UTF-8 before searching.
pub struct Encoding {
  priv kind : EncKind
  priv name : String
}

///|
fn is_ascii_whitespace(c : UInt16) -> Bool {
  c is ('\t' | '\n' | '\u{0C}' | '\r' | ' ')
}

///|
/// Implements the Encoding Standard's "get an encoding" for `label`: leading
/// and trailing ASCII whitespace is removed and the label is matched ASCII
/// case-insensitively.
fn lookup_label(label : String) -> EncKind? {
  let mut start = 0
  let mut end = label.length()
  while start < end && is_ascii_whitespace(label[start]) {
    start += 1
  }
  while end > start && is_ascii_whitespace(label[end - 1]) {
    end -= 1
  }
  let sb = StringBuilder()
  for i in start..<end {
    let c = label[i].to_int()
    if c >= 0x80 {
      // All labels are ASCII.
      return None
    }
    let c = if c >= 'A'.to_int() && c <= 'Z'.to_int() { c + 0x20 } else { c }
    sb.write_char(c.unsafe_to_char())
  }
  encoding_kind_for_label(sb.to_string())
}

///|
/// Looks up an encoding by its WHATWG label, like encoding_rs's
/// `Encoding::for_label_no_replacement`: every label of the Encoding Standard
/// is accepted (ASCII case-insensitively, ignoring surrounding ASCII
/// whitespace) except those of the "replacement" encoding.
pub fn Encoding::new(label : String) -> Encoding raise SearchError {
  guard lookup_label(label) is Some(kind) else {
    raise ConfigError("grep config error: unknown encoding: \{label}")
  }
  { kind, name: kind.name(), }
}

///|
/// Returns the canonical WHATWG name of the encoding, e.g. `Shift_JIS`.
pub fn Encoding::name(self : Encoding) -> String {
  self.name
}

///|
/// Returns the encoding indicated by a byte order mark at the start of
/// `buf[start:end]`, along with the BOM length.
fn sniff_bom(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> (EncKind, Int32)? {
  let n = end - start
  if n >= 3 &&
    buf[start] == b'\xEF' &&
    buf[start + 1] == b'\xBB' &&
    buf[start + 2] == b'\xBF' {
    Some((Utf8, 3))
  } else if n >= 2 && buf[start] == b'\xFF' && buf[start + 1] == b'\xFE' {
    Some((Utf16LE, 2))
  } else if n >= 2 && buf[start] == b'\xFE' && buf[start + 1] == b'\xFF' {
    Some((Utf16BE, 2))
  } else {
    None
  }
}

///|
/// Returns true if the slice begins with a UTF-8 or UTF-16 BOM.
pub fn slice_has_bom(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Bool {
  sniff_bom(buf, start, end) is Some(_)
}

///|
/// The encoding of a BOM at the start of the first (up to) 3 bytes of a
/// stream, like encoding_rs_io's `PossibleBom::encoding`: a BOM is only
/// recognized when 3 bytes could be peeked.
fn peeked_bom(peek : FixedArray[Byte], len : Int32) -> EncKind? {
  if len < 3 {
    return None
  }
  match sniff_bom(peek, 0, len) {
    Some((kind, _)) => Some(kind)
    None => None
  }
}

///|
/// The number of leading peeked bytes stripped as a BOM, like
/// encoding_rs_io's `PossibleBom::as_slice(false)`.
fn peeked_bom_len(peek : FixedArray[Byte], len : Int32) -> Int32 {
  if len <= 1 {
    0
  } else if (peek[0] == b'\xFF' && peek[1] == b'\xFE') ||
    (peek[0] == b'\xFE' && peek[1] == b'\xFF') {
    2
  } else if len == 3 &&
    peek[0] == b'\xEF' &&
    peek[1] == b'\xBB' &&
    peek[2] == b'\xBF' {
    3
  } else {
    0
  }
}

///|
/// A reader that sniffs a BOM and transcodes its input to UTF-8. It mirrors
/// encoding_rs_io's `DecodeReaderBytes` as configured by ripgrep (UTF-8
/// passthrough, BOM stripping and override), including how input is read
/// and decoded in chunks, which affects edge cases at the end of the input.
priv struct DecodeReader {
  inner : &Reader
  encoding : EncKind?
  bom_sniffing : Bool
  mut started : Bool
  // The decoder, or `None` to pass the input through unchanged.
  mut decoder : LegacyDecoder?
  // The first (up to) 3 bytes, peeked to sniff a BOM; `peek[peek_pos:
  // peek_len]` are returned by the first read on their own (like
  // encoding_rs_io's `BomPeeker`).
  peek : FixedArray[Byte]
  mut peek_pos : Int32
  mut peek_len : Int32
  mut peek_done : Bool
  // Raw input chunk to decode.
  raw : FixedArray[Byte]
  // Whether the input has been fully read and decoded.
  mut exhausted : Bool
  // Decoded output waiting to be returned.
  out : Buffer
  mut out_pos : Int32
  mut out_bytes : Bytes
}

///|
fn DecodeReader::new(
  inner : &Reader,
  encoding : EncKind?,
  bom_sniffing : Bool,
) -> DecodeReader {
  {
    inner,
    encoding,
    bom_sniffing,
    started: false,
    decoder: None,
    peek: FixedArray::make(3, b'\x00'),
    peek_pos: 0,
    peek_len: 0,
    peek_done: false,
    raw: FixedArray::make(8192, b'\x00'),
    exhausted: false,
    out: Buffer(),
    out_pos: 0,
    out_bytes: b"",
  }
}

///|
async fn DecodeReader::start(self : DecodeReader) -> Unit {
  self.started = true
  // Peek exactly 3 bytes (or until EOF).
  while self.peek_len < 3 {
    let n = self.inner.read(self.peek, self.peek_len, 3 - self.peek_len)
    if n == 0 {
      break
    }
    self.peek_len += n
  }
  if self.bom_sniffing {
    // The BOM is stripped even when it is too short to be recognized.
    self.peek_pos = peeked_bom_len(self.peek, self.peek_len)
  }
  self.decoder = self.encoding.map(k => LegacyDecoder::new(k, bom_removal=true))
  if self.bom_sniffing && peeked_bom(self.peek, self.peek_len) is Some(kind) {
    // A UTF-8 BOM keeps the configured decoder (UTF-8 is passed through),
    // while a UTF-16 BOM overrides it.
    if kind != Utf8 {
      self.decoder = Some(LegacyDecoder::new(kind, bom_removal=true))
    }
  }
}

///|
/// Reads from the input, returning the remaining peeked bytes first (on
/// their own).
async fn DecodeReader::read_input(
  self : DecodeReader,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Int32 {
  if !self.peek_done {
    if self.peek_pos < self.peek_len {
      let n = if self.peek_len - self.peek_pos < len {
        self.peek_len - self.peek_pos
      } else {
        len
      }
      self.peek.blit_to(buf, len=n, src_offset=self.peek_pos, dst_offset=start)
      self.peek_pos += n
      return n
    }
    self.peek_done = true
  }
  self.inner.read(buf, start, len)
}

///|
fn push_char(out : Buffer, c : Int32) -> Unit {
  if c < 0x80 {
    out.write_byte(c.to_byte())
  } else if c < 0x800 {
    out.write_byte((0xC0 | (c >> 6)).to_byte())
    out.write_byte((0x80 | (c & 0x3F)).to_byte())
  } else if c < 0x10000 {
    out.write_byte((0xE0 | (c >> 12)).to_byte())
    out.write_byte((0x80 | ((c >> 6) & 0x3F)).to_byte())
    out.write_byte((0x80 | (c & 0x3F)).to_byte())
  } else {
    out.write_byte((0xF0 | (c >> 18)).to_byte())
    out.write_byte((0x80 | ((c >> 12) & 0x3F)).to_byte())
    out.write_byte((0x80 | ((c >> 6) & 0x3F)).to_byte())
    out.write_byte((0x80 | (c & 0x3F)).to_byte())
  }
}

///|
/// Copies pending decoded output into `buf[start:start+len]`.
fn DecodeReader::serve(
  self : DecodeReader,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Int32 {
  let avail = self.out_bytes.length() - self.out_pos
  let n = if avail < len { avail } else { len }
  buf.blit_from_bytes(start, self.out_bytes, self.out_pos, n)
  self.out_pos += n
  n
}

///|
/// Takes the output decoded so far for serving.
fn DecodeReader::take_out(self : DecodeReader) -> Unit {
  self.out_bytes = self.out.to_bytes()
  self.out_pos = 0
  self.out.reset()
}

///|
impl Reader for DecodeReader with fn read(self, buf, start, len) {
  if !self.started {
    self.start()
  }
  guard self.decoder is Some(dec) else {
    return self.read_input(buf, start, len)
  }
  if self.out_pos < self.out_bytes.length() {
    return self.serve(buf, start, len)
  }
  if self.exhausted || len == 0 {
    return 0
  }
  // Like encoding_rs_io's `transcode`: read a chunk and decode it (not as
  // the last chunk); return as soon as some output was produced. At the end
  // of the input the decoder is called once more with empty input before
  // being flushed (which matters to some decoders, see `decode_empty`).
  let mut n = self.read_input(self.raw, 0, self.raw.length())
  if n == 0 {
    self.exhausted = true
  }
  for ;; {
    if n == 0 {
      dec.decode_empty()
    } else {
      dec.feed(self.raw, 0, n, self.out)
    }
    if self.out.length() > 0 {
      self.take_out()
      return self.serve(buf, start, len)
    }
    n = self.read_input(self.raw, 0, self.raw.length())
    if n == 0 {
      self.exhausted = true
      dec.finish(self.out)
      self.take_out()
      return self.serve(buf, start, len)
    }
  }
}
