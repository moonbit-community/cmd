///|
/// The maximum number of bytes to execute a search to account for
/// look-ahead (only active in multi-line mode).
const MAX_LOOK_AHEAD : Int32 = 128

///|
/// A type for handling replacements while amortizing allocation.
priv struct Replacer {
  mut space : Space?
}

///|
priv struct Space {
  /// The place to store capture locations.
  caps : @matcher.Captures
  /// The place to write a replacement to.
  dst : @termcolor.ByteVec
  /// The place to store match offsets in terms of `dst`.
  matches : Array[@matcher.Match]
  /// Scratch space for capture interpolation.
  scratch : @buffer.Buffer
}

///|
fn Replacer::new() -> Replacer {
  { space: None, }
}

///|
/// Executes a replacement on `hay[hs:he]` by replacing all matches in
/// `range_start..range_end` (relative to `hs`) with `replacement`.
fn Replacer::replace_all(
  self : Replacer,
  searcher : @searcher.Searcher,
  matcher : &@matcher.Matcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  range_start : Int32,
  range_end : Int32,
  replacement : Bytes,
) -> Unit {
  let is_multi_line = searcher.multi_line_with_matcher(matcher)
  let mut he = he
  // Get the line terminator that was removed (if any) so we can add it
  // back.
  let (lt_start, lt_end) = if is_multi_line {
    if he - (hs + range_end) >= MAX_LOOK_AHEAD {
      he = hs + range_end + MAX_LOOK_AHEAD
    }
    (0, 0)
  } else {
    // When searching a single line, we should remove the line terminator.
    // Otherwise, it's possible for the regex (via look-around) to observe
    // the line terminator and not match because of it.
    let (m, ts, te) = trim_line_terminator(
      searcher,
      hay,
      hs,
      @matcher.Match::new(0, range_end),
    )
    he = hs + m.end
    (ts, te)
  }
  let space = self.allocate(matcher)
  space.dst.clear()
  space.matches.clear()
  replace_with_captures_in_context(
    matcher,
    hay,
    hs,
    he,
    lt_start,
    lt_end,
    range_start,
    range_end,
    space.caps,
    space.dst,
    (caps, dst) => {
      let start = dst.length()
      space.scratch.reset()
      caps.interpolate(
        name => matcher.capture_index(name),
        hay,
        hs,
        replacement,
        space.scratch,
      )
      dst.extend_bytes(space.scratch.contents())
      let end = dst.length()
      space.matches.push(@matcher.Match::new(start, end))
      true
    },
  )
}

///|
/// Return the result of the prior replacement and the match offsets for
/// all replacement occurrences within the returned replacement buffer.
///
/// If no replacement has occurred then `None` is returned.
fn Replacer::replacement(
  self : Replacer,
) -> (@termcolor.ByteVec, Array[@matcher.Match])? {
  match self.space {
    None => None
    Some(space) =>
      if space.matches.is_empty() {
        None
      } else {
        Some((space.dst, space.matches))
      }
  }
}

///|
/// Clear space used for performing a replacement.
fn Replacer::clear(self : Replacer) -> Unit {
  if self.space is Some(space) {
    space.dst.clear()
    space.matches.clear()
  }
}

///|
fn Replacer::allocate(self : Replacer, matcher : &@matcher.Matcher) -> Space {
  match self.space {
    Some(space) => space
    None => {
      let space = {
        caps: matcher.new_captures(),
        dst: @termcolor.ByteVec::new(),
        matches: [],
        scratch: Buffer(),
      }
      self.space = Some(space)
      space
    }
  }
}

///|
/// A simple layer of abstraction over either a match or a contextual line
/// reported by the searcher. The bytes are `buf[start:end]` and all match
/// offsets are relative to `start`.
priv struct Sunk {
  mut buf : FixedArray[Byte]
  mut start : Int32
  mut end : Int32
  mut absolute_byte_offset : Int64
  mut line_number : Int64?
  mut context_kind : @searcher.SinkContextKind?
  mut matches : Array[@matcher.Match]
  mut original_matches : Array[@matcher.Match]
}

///|
fn Sunk::empty() -> Sunk {
  {
    buf: [],
    start: 0,
    end: 0,
    absolute_byte_offset: 0,
    line_number: None,
    context_kind: None,
    matches: [],
    original_matches: [],
  }
}

///|
/// Shared empty values for `Sunk::set_empty` (never mutated).
let empty_buf : FixedArray[Byte] = []

///|
let empty_matches : Array[@matcher.Match] = []

///|
/// Resets `self` to the empty state (see `Sunk::empty`).
fn Sunk::set_empty(self : Sunk) -> Unit {
  self.buf = empty_buf
  self.start = 0
  self.end = 0
  self.absolute_byte_offset = 0
  self.line_number = None
  self.context_kind = None
  self.matches = empty_matches
  self.original_matches = empty_matches
}

///|
/// Sets `self` to the data of a matching line.
fn Sunk::set_match(
  self : Sunk,
  sunk : @searcher.SinkMatch,
  original_matches : Array[@matcher.Match],
  replacement : (@termcolor.ByteVec, Array[@matcher.Match])?,
) -> Unit {
  match replacement {
    Some((dst, ms)) => {
      self.buf = dst.storage()
      self.start = 0
      self.end = dst.length()
      self.matches = ms
    }
    None => {
      self.buf = sunk.buf
      self.start = sunk.buf_start + sunk.start
      self.end = sunk.buf_start + sunk.end
      self.matches = original_matches
    }
  }
  self.absolute_byte_offset = sunk.absolute_byte_offset
  self.line_number = sunk.line_number
  self.context_kind = None
  self.original_matches = original_matches
}

///|
/// Sets `self` to the data of a context line.
fn Sunk::set_context(
  self : Sunk,
  sunk : @searcher.SinkContext,
  original_matches : Array[@matcher.Match],
  replacement : (@termcolor.ByteVec, Array[@matcher.Match])?,
) -> Unit {
  match replacement {
    Some((dst, ms)) => {
      self.buf = dst.storage()
      self.start = 0
      self.end = dst.length()
      self.matches = ms
    }
    None => {
      self.buf = sunk.buf
      self.start = sunk.start
      self.end = sunk.end
      self.matches = original_matches
    }
  }
  self.absolute_byte_offset = sunk.absolute_byte_offset
  self.line_number = sunk.line_number
  self.context_kind = Some(sunk.kind)
  self.original_matches = original_matches
}

///|
fn Sunk::len(self : Sunk) -> Int32 {
  self.end - self.start
}

///|
/// A simple encapsulation of a file path used by a printer.
///
/// This represents any transforms that we might want to perform on the
/// path, such as replacing its separator with something else.
priv struct PrinterPath {
  /// The path as a string (after separator replacement).
  path : String
  /// The bytes that are printed (the OS form of the path, see `osstr`).
  bytes : Bytes
  mut hyperlink : HyperlinkPath??
}

///|
fn PrinterPath::new(path : String) -> PrinterPath {
  // Paths are OS strings: restore any bytes that aren't valid UTF-8.
  { path, bytes: @osstr.encode(path), hyperlink: None, }
}

///|
/// Set the separator on this path. When set, the path's `/` separators are
/// replaced with the one given.
fn PrinterPath::with_separator(self : PrinterPath, sep : Byte?) -> PrinterPath {
  guard sep is Some(sep) else { return self }
  let bytes = Bytes::makei(self.bytes.length(), i => {
    let b = self.bytes[i]
    if b == b'/' {
      sep
    } else {
      b
    }
  })
  let path = if sep < b'\x80' {
    self.path.replace_all(
      old="/",
      new=sep.to_int().unsafe_to_char().to_string(),
    )
  } else {
    self.path
  }
  { path, bytes, hyperlink: None, }
}

///|
/// Return this path as a hyperlink (computed lazily).
async fn PrinterPath::as_hyperlink(
  self : PrinterPath,
  env : HyperlinkEnvironment,
) -> HyperlinkPath? {
  match self.hyperlink {
    Some(h) => h
    None => {
      let h = HyperlinkPath::from_path(self.path, env)
      self.hyperlink = Some(h)
      h
    }
  }
}

///|
/// Scratch space for formatting decimals without allocating.
let decimal_scratch : FixedArray[Byte] = FixedArray::make(20, b'\x00')

///|
/// Writes the decimal digits of `n` (as an unsigned integer) to the end of
/// `decimal_scratch`, returning the index of the first digit.
fn format_decimal(n : Int64) -> Int32 {
  let buf = decimal_scratch
  let mut n = n.reinterpret_as_uint64()
  let mut i = buf.length()
  while true {
    i -= 1
    buf[i] = (b'0'.to_uint64() + n % 10).to_byte()
    n = n / 10
    if n == 0 {
      break
    }
  }
  i
}

///|
fn is_ascii_space(b : Byte) -> Bool {
  b is (b'\t' | b'\n' | b'\x0B' | b'\x0C' | b'\r' | b' ')
}

///|
/// Trim prefix ASCII spaces from `hay[hs + range.start : hs + range.end]`
/// and return the corresponding range.
///
/// This stops trimming a prefix as soon as it sees non-whitespace or a line
/// terminator.
fn trim_ascii_prefix(
  line_term : @matcher.LineTerminator,
  hay : FixedArray[Byte],
  hs : Int32,
  range : @matcher.Match,
) -> @matcher.Match {
  let lt = line_term.as_bytes()
  let mut count = 0
  for i in range.start..<range.end {
    let b = hay[hs + i]
    if is_ascii_space(b) && !bytes_contains(lt, b) {
      count += 1
    } else {
      break
    }
  }
  range.with_start(range.start + count)
}

///|
/// Finds all matches in `hay[hs:he]` that start in
/// `range_start..range_end` (offsets relative to `hs`), accounting for
/// multi-line look-ahead and stripping the line terminator in single-line
/// mode.
fn find_iter_at_in_context(
  searcher : @searcher.Searcher,
  matcher : &@matcher.Matcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  range_start : Int32,
  range_end : Int32,
  matched : (@matcher.Match) -> Bool,
) -> Unit {
  // This strange dance is to account for the possibility of look-ahead in
  // the regex. See grep-printer's util.rs for the full story.
  let is_multi_line = searcher.multi_line_with_matcher(matcher)
  let mut he = he
  if is_multi_line {
    if he - (hs + range_end) >= MAX_LOOK_AHEAD {
      he = hs + range_end + MAX_LOOK_AHEAD
    }
  } else {
    // When searching a single line, we should remove the line terminator.
    // Otherwise, it's possible for the regex (via look-around) to observe
    // the line terminator and not match because of it.
    let (m, _, _) = trim_line_terminator(
      searcher,
      hay,
      hs,
      @matcher.Match::new(0, range_end),
    )
    he = hs + m.end
  }
  @matcher.find_iter_at(matcher, hay, hs, he, range_start, m => {
    if m.start >= range_end {
      return false
    }
    matched(m)
  })
}

///|
/// Given a buffer `hay` (offsets relative to `hs`) and a line range, if
/// there is a line terminator at the end of the given range, then the range
/// is trimmed to remove the line terminator. Returns the new range along
/// with the (relative) bounds of the removed line terminator.
fn trim_line_terminator(
  searcher : @searcher.Searcher,
  hay : FixedArray[Byte],
  hs : Int32,
  line : @matcher.Match,
) -> (@matcher.Match, Int32, Int32) {
  let lineterm = searcher.line_terminator()
  if lineterm.is_suffix(hay, hs + line.start, hs + line.end) {
    let mut end = line.end - 1
    if lineterm.is_crlf() && end > 0 && hay[hs + end - 1] == b'\r' {
      end -= 1
    }
    (line.with_end(end), end, line.end)
  } else {
    (line, line.end, line.end)
  }
}

///|
/// Like `Matcher::replace_with_captures_at`, but accepts an end bound.
fn replace_with_captures_in_context(
  matcher : &@matcher.Matcher,
  hay : FixedArray[Byte],
  hs : Int32,
  he : Int32,
  lt_start : Int32,
  lt_end : Int32,
  range_start : Int32,
  range_end : Int32,
  caps : @matcher.Captures,
  dst : @termcolor.ByteVec,
  append : (@matcher.Captures, @termcolor.ByteVec) -> Bool,
) -> Unit {
  let mut last_match = range_start
  @matcher.captures_iter_at(matcher, hay, hs, he, range_start, caps, caps => {
    let m = caps.get(0).unwrap()
    if m.start >= range_end {
      return false
    }
    dst.extend_slice(hay, hs + last_match, hs + m.start)
    last_match = m.end
    append(caps, dst)
  })
  let len = he - hs
  let end = if last_match > range_end {
    len
  } else if len < range_end {
    len
  } else {
    range_end
  }
  dst.extend_slice(hay, hs + last_match, hs + end)
  // Add back any line terminator.
  dst.extend_slice(hay, hs + lt_start, hs + lt_end)
}

///|
/// Counts the lines in `buf[start:end]` like Rust's `LineIter` would.
fn count_lines_in(
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
  line_term : Byte,
) -> Int64 {
  let mut n = 0L
  let mut last = start
  for i in start..<end {
    if buf[i] == line_term {
      n += 1
      last = i + 1
    }
  }
  if last < end {
    n += 1
  }
  n
}

///|
fn bytes_contains(bs : Bytes, b : Byte) -> Bool {
  for x in bs {
    if x == b {
      return true
    }
  }
  false
}
