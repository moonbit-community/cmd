///|
test "cut normalizes overlaps while preserving adjacent range boundaries" {
  assert_eq(parse_list("3-4,1-2"), [(1, 2), (3, 4)])
  assert_eq(parse_list("1-2,2-3,2"), [(1, 3)])
  assert_eq(complement_ranges(parse_list("2,4-5")), [
    (1, 1),
    (3, 3),
    (6, open_end),
  ])
  assert_eq(complement_ranges(parse_list("1-")), [])
  assert_eq(complement_ranges(parse_list("1-2,3-4")), [(5, open_end)])
}

///|
test "cut output separators join explicit ranges and selected fields" {
  assert_eq(
    cut_characters(b"abcdef", parse_list("1-2,3-4"), Some(b"|")),
    b"ab|cd",
  )
  assert_eq(
    cut_characters(b"abcdef", parse_list("3,1,2"), Some(b"::")),
    b"a::b::c",
  )
  assert_eq(
    cut_characters(b"abcdef", parse_list("1-3,2-4"), Some(b"|")),
    b"abcd",
  )
  assert_eq(
    cut_characters(b"abcdef", complement_ranges(parse_list("2,4")), Some(b"|")),
    b"a|c|ef",
  )
  assert_eq(cut_characters(b"ab", parse_list("4-"), Some(b"|")), b"")
  assert_eq(
    cut_fields(b"a:b:c", parse_list("1,3"), b':', false, b"::"),
    Some(b"a::c"),
  )
  assert_eq(
    cut_fields(b"a::c", parse_list("1-3"), b':', false, b"|"),
    Some(b"a||c"),
  )
  assert_eq(output_delimiter_bytes(""), b"\x00")
}

///|
async fn same_delimiter_output(
  input : Bytes,
  spec : String,
  only_delimited : Bool,
) -> Bytes {
  let reader = @io.MemoryReader(writer => writer.write(input))
  defer reader.close()
  let scanner = @stream.LineScanner::new(reader, delimiter=b'\x00')
  let output = @io.MemoryReader(writer => {
    cut_same_delimiter(
      scanner,
      parse_list(spec),
      b'\x00',
      only_delimited,
      b"|",
      writer~,
    )
  })
  defer output.close()
  output.read_all().binary()
}

///|
async fn no_fields_output(input : Bytes) -> Bytes {
  let reader = @io.MemoryReader(writer => writer.write(input))
  defer reader.close()
  let output = @io.MemoryReader(writer => {
    cut_no_fields(reader, b':', b'\n', false, writer~)
  })
  defer output.close()
  output.read_all().binary()
}

///|
async test "cut field selection preserves undelimited records and NUL fields" {
  assert_eq(
    cut_fields(b"whole", parse_list("2-"), b':', false, b"|"),
    Some(b"whole"),
  )
  assert_eq(cut_fields(b"whole", parse_list("2-"), b':', true, b"|"), None)
  assert_eq(cut_fields(b"a:b", parse_list("3-"), b':', false, b"|"), Some(b""))
  assert_eq(
    cut_fields(b"a\x00b\x00c", parse_list("1,3"), b'\x00', false, b"\x00"),
    Some(b"a\x00c"),
  )
  assert_eq(same_delimiter_output(b"a\x00b\x00c\n", "2", false), b"b\x00")
  assert_eq(same_delimiter_output(b"a\x00b\x00c\n", "1,3", true), b"a|c\n\x00")
  assert_eq(same_delimiter_output(b"a\x00", "2", false), b"\x00")
  assert_eq(same_delimiter_output(b"a\x00", "2", true), b"")
  assert_eq(same_delimiter_output(b"whole", "2", false), b"whole\x00")
  assert_eq(same_delimiter_output(b"whole", "2", true), b"")
  assert_eq(same_delimiter_output(b"", "1", false), b"")
  for
    (input, expected) in [
      (b"plain", b""),
      (b"plain\n", b"plain\n"),
      (b"x:y\nplain", b"\n"),
      (b"x:y\nplain\n", b"\n\n"),
      (b"plain\nx:y", b"\n"),
      (b"plain\nplain", b"plain\n"),
      (b"x:y", b""),
    ] {
    assert_eq(no_fields_output(input), expected)
  }
}

///|
fn cut_characters(
  line : BytesView,
  ranges : Array[(Int32, Int32)],
  separator : Bytes?,
) -> Bytes {
  let output = @buffer.Buffer()
  cut_characters_into(line, ranges, separator, output)
  output.to_bytes()
}

///|
fn cut_fields(
  line : BytesView,
  ranges : Array[(Int32, Int32)],
  delimiter : Byte,
  only_delimited : Bool,
  separator : Bytes,
) -> Bytes? {
  let output = @buffer.Buffer()
  if cut_fields_into(
      line,
      ranges,
      Bytes::from_array([delimiter]),
      only_delimited,
      separator,
      output,
    ) {
    Some(output.to_bytes())
  } else {
    None
  }
}
