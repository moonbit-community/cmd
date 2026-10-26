///|
async test "block rejection preserves offsets and an incomplete matching tail" {
  let reader = @io.MemoryReader(writer => writer.write(b"dle\n"))
  defer reader.close()
  let input = GrepInput::new(reader, b'\n', Text)
  input.bytes = b"first\nsecond\nnee"
  let matcher = Matcher::Fixed([b"needle"], false, false)
  input.skip_nonmatching(matcher, false)
  assert_eq(input.position, 13)
  assert_eq(input.offset, 13L)
  assert_eq(input.number, 2L)
  let record = input.next().unwrap()
  assert_eq(record.data, b"needle")
  assert_eq(record.offset, 13L)
  assert_eq(record.number, 3L)
}

///|
test "block prefilter is conservative for alternatives empty matches and folding" {
  for
    (source, data) in [
      ("a?", b"zzz"),
      ("foo|bar", b"bar\n"),
      ("(abc)?x", b"x\n"),
      ("ab.*cd", b"ab cd\n"),
    ] {
    let matcher = Matcher::Regular(
      [@bytere.compile(source, extended=true).record_matcher()],
      false,
      false,
    )
    assert_true(matcher.may_match_block(data, false))
  }
  assert_true(
    Matcher::Fixed([b"", b"x"], false, false).may_match_block(b"\n", false),
  )
  assert_true(
    Matcher::Fixed([b"abc"], false, false).may_match_block(b"ABC\n", true),
  )
  let matcher = Matcher::Regular(
    [@bytere.compile("abc.*uvwxyz", extended=true).record_matcher()],
    false,
    false,
  )
  assert_true(!matcher.may_match_block(b"abc nothing\n", false))
}

///|
async test "counting batches retain inverted matches NUL records and final fragments" {
  for delimiter in [b'\n', b'\x00'] {
    for invert in [false, true] {
      let ending = Bytes::from_array([delimiter])
      let data = b"no" +
        ending +
        b"needle" +
        ending +
        b"no" +
        ending +
        b"needle"
      let reader = @io.MemoryReader(writer => writer.write(data))
      defer reader.close()
      let output : CapturedOutput = { bytes: [], }
      let errors : CapturedOutput = { bytes: [], }
      let options = {
        ..streaming_options(),
        count: true,
        invert,
        zero_terminated: delimiter == b'\x00',
      }
      assert_true(
        process_reader(
          reader,
          "-",
          Fixed([b"needle"], false, false),
          options,
          false,
          stdout=output,
          stderr=errors,
        ),
      )
      assert_eq(Bytes::from_array(output.bytes), b"2\n")
      assert_eq(errors.bytes.length(), 0)
    }
  }
}
