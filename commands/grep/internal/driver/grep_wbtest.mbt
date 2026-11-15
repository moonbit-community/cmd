///|
async test "record splitting preserves content and byte offsets" {
  let reader = @io.MemoryReader(writer => writer.write(b"zero\nneedle\n"))
  defer reader.close()
  let input = GrepInput::new(reader, b'\n', Text)
  guard input.next() is Some(first) else { fail("missing first record") }
  guard input.next() is Some(second) else { fail("missing second record") }
  assert_eq(first.data, b"zero")
  assert_eq(second.data, b"needle")
  assert_eq(second.offset, 5L)
  assert_true(input.next() is None)
}

///|
async test "streamed records retain views and partial records before input errors" {
  let reader = @io.MemoryReader(writer => {
    writer.write(b"first\npart")
    @async.sleep(1)
    writer.write(b"ial\nlast")
    @async.sleep(1)
    fail("input failure")
  })
  defer reader.close()
  let input = GrepInput::new(reader, b'\n', Text)
  guard input.next() is Some(first) else { fail("first record") }
  guard input.next() is Some(second) else { fail("second record") }
  guard input.next() is Some(last) else { fail("partial final record") }
  assert_eq(first.data, b"first")
  assert_true(first.terminated)
  assert_eq(second.data, b"partial")
  assert_eq(second.offset, 6L)
  assert_eq(last.data, b"last")
  assert_true(!last.terminated)
  assert_eq(last.offset, 14L)
  try input.next() catch {
    error => assert_true(error.to_string().contains("input failure"))
  } noraise {
    _ => fail("missing input error")
  }
}

///|
test "fixed matcher accepts byte-decoded records" {
  let matcher = Matcher::Fixed([b"needle"], false, false)
  let decoded = bytes_as_string(b"needle")
  assert_eq(decoded, "needle")
  assert_true(matcher.matches_record(b"needle", false))
  let word = Matcher::Fixed([b"ab"], false, true)
  assert_true(word.matches_record(b"!AB?", true))
  assert_true(!word.matches_record(b"xAB", true))
}

///|
priv struct CapturedOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for CapturedOutput with fn write_once(
  self,
  bytes,
  offset~,
  len~,
) {
  for index in offset..<(offset + len) {
    self.bytes.push(bytes[index])
  }
  len
}

///|
fn streaming_options() -> GrepOptions {
  {
    fixed: true,
    extended: false,
    only_matching: false,
    ignore_case: false,
    invert: false,
    line_number: false,
    byte_offset: false,
    count: false,
    files_with_matches: false,
    files_without_match: false,
    quiet: false,
    force_filename: false,
    no_filename: false,
    whole_line: false,
    word: false,
    recursive: false,
    suppress_messages: false,
    zero_terminated: false,
    before_context: 0,
    after_context: 0,
    context_enabled: false,
    binary_mode: Report,
  }
}

///|
async test "streamed grep preserves binary decisions and error prefixes" {
  let matcher = Matcher::Fixed([b"needle"], false, false)
  for
    (tail, mode, selected, diagnostic) in [
      (b"other", Report, true, b""),
      (
        b"needle",
        Report,
        true,
        b"grep: (standard input): binary file matches\n",
      ),
      (b"needle", WithoutMatch, false, b""),
    ] {
    let input = @io.MemoryReader(writer => {
      writer.write(
        b"needle\n" + Bytes::make(200000, b'x') + b"\n\x00" + tail + b"\n",
      )
    })
    defer input.close()
    let output : CapturedOutput = { bytes: [], }
    let errors : CapturedOutput = { bytes: [], }
    let options = { ..streaming_options(), binary_mode: mode, }
    assert_eq(
      process_reader(
        input,
        "-",
        matcher,
        options,
        false,
        stdout=output,
        stderr=errors,
      ),
      selected,
    )
    assert_eq(Bytes::from_array(output.bytes), b"needle\n")
    assert_eq(Bytes::from_array(errors.bytes), diagnostic)
  }
  let input = @io.MemoryReader(writer => {
    writer.write(b"needle\npartneedle")
    @async.sleep(1)
    fail("later read failed")
  })
  defer input.close()
  let output : CapturedOutput = { bytes: [], }
  let errors : CapturedOutput = { bytes: [], }
  let options = { ..streaming_options(), binary_mode: Text, }
  try
    process_reader(
      input,
      "-",
      matcher,
      options,
      false,
      stdout=output,
      stderr=errors,
    )
  catch {
    error => assert_true(error.to_string().contains("later read failed"))
  } noraise {
    _ => fail("missing read failure")
  }
  assert_eq(Bytes::from_array(output.bytes), b"needle\npartneedle\n")
  assert_eq(errors.bytes.length(), 0)
}

///|
async test "streamed quiet grep completes while its producer remains open" {
  let input = @io.MemoryReader(writer => {
    writer.write(b"needle\n")
    @async.sleep(10000)
  })
  defer input.close()
  let output : CapturedOutput = { bytes: [], }
  let errors : CapturedOutput = { bytes: [], }
  let options = { ..streaming_options(), quiet: true, }
  let matcher = Matcher::Fixed([b"needle"], false, false)
  assert_true(
    @async.with_timeout(1000, () => {
      process_reader(
        input,
        "-",
        matcher,
        options,
        false,
        stdout=output,
        stderr=errors,
      )
    }),
  )
  assert_eq(output.bytes.length(), 0)
  assert_eq(errors.bytes.length(), 0)
}

///|
test "BRE operators are literal until escaped and ERE operators are active" {
  let basic = @bytere.compile("a+b")
  assert_true(basic.find_span("a+b") is Some(_))
  assert_true(basic.find_span("aaab") is None)
  assert_true(@bytere.compile("a\\+b").find_span("aaab") is Some(_))
  assert_true(
    @bytere.compile("a+b", extended=true).find_span("aaab") is Some(_),
  )
  assert_true(
    @bytere.compile("a\\+b", extended=true).find_span("a+b") is Some(_),
  )
  assert_true(@bytere.compile("\\(ab\\)\\{2\\}").find_span("abab") is Some(_))
}

///|
test "only matching chooses leftmost longest across alternatives and patterns" {
  let regex = Matcher::Regular(
    [@bytere.compile("a|aa", extended=true).record_matcher()],
    false,
    false,
  )
  assert_eq(regex.next_match("zaaa", 0), Some((1, 3)))
  assert_eq(regex.next_match("zaaa", 3), Some((3, 4)))
  let fixed = Matcher::Fixed([b"a", b"aa"], false, false)
  assert_eq(fixed.next_match("zaaa", 0), Some((1, 3)))
}

///|
test "only matching preserves anchors and word boundaries on resumed searches" {
  let anchored = Matcher::Regular(
    [@bytere.compile("^a|b$", extended=true).record_matcher()],
    false,
    false,
  )
  assert_eq(anchored.next_match("aaab", 0), Some((0, 1)))
  assert_eq(anchored.next_match("aaab", 1), Some((3, 4)))
  let words = Matcher::Regular(
    [@bytere.compile("a|aa", extended=true).record_matcher()],
    false,
    true,
  )
  assert_eq(words.next_match("za aa a!", 0), Some((3, 5)))
  assert_eq(words.next_match("za aa a!", 5), Some((6, 7)))
}

///|
test "multiple expressions keep independent backreferences and word filtering" {
  let matcher = Matcher::Regular(
    [
      @bytere.compile("\\(a\\)\\1").record_matcher(),
      @bytere.compile("\\(b\\)\\1").record_matcher(),
    ],
    false,
    false,
  )
  assert_eq(matcher.next_match("zbb aa", 0), Some((1, 3)))
  assert_eq(matcher.next_match("zbb aa", 3), Some((4, 6)))
  let words = Matcher::Regular(
    [@bytere.compile("foo.|foo", extended=true).record_matcher()],
    false,
    true,
  )
  assert_eq(words.next_match("foo.a", 0), Some((0, 3)))
}
