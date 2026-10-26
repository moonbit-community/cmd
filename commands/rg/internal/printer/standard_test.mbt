///|
let sherlock : String =
  #|For the Doctor Watsons of this world, as opposed to the Sherlock
  #|Holmeses, success in the province of detective work must always
  #|be, to a very large extent, the result of luck. Sherlock Holmes
  #|can extract a clew from a wisp of straw or a flake of cigar ash;
  #|but Doctor Watson has to have it taken out for him and dusted,
  #|and exhibited clearly, with a label attached.

///|
fn str_bytes(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn reader(b : Bytes) -> &@searcher.Reader {
  @searcher.SliceReader::from_bytes(b)
}

///|
fn contents(out : @termcolor.ByteVec) -> String {
  @utf8.decode_lossy(out.to_bytes())
}

///|
async test "reports_match" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  let sink = printer.sink(matcher)
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), sink)
  assert_true(sink.has_match())
  let matcher = @grep_regex.RegexMatcher::new("zzzzz")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  let sink = printer.sink(matcher)
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), sink)
  assert_false(sink.has_match())
}

///|
async test "reports_binary" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  let sink = printer.sink(matcher)
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), sink)
  assert_true(sink.binary_byte_offset() is None)
  let matcher = @grep_regex.RegexMatcher::new(".+")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  let sink = printer.sink(matcher)
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .binary_detection(@searcher.BinaryDetection::BinaryQuit(b'\x00'))
  .build()
  .search_reader(matcher, reader(b"abc\x00"), sink)
  assert_eq(sink.binary_byte_offset(), Some(3))
}

// SKIPPED: reports_stats

// SKIPPED: reports_stats_multiple

///|
async test "context_break" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .separator_context(Some(b"--abc--"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--abc--
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "context_break_multiple_no_heading" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .separator_search(Some(b"--xyz--"))
    .separator_context(Some(b"--abc--"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--abc--
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|--xyz--
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--abc--
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "context_break_multiple_heading" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .heading(true)
    .separator_search(Some(b"--xyz--"))
    .separator_context(Some(b"--abc--"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--abc--
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|--xyz--
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--abc--
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "path" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .path(false)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  let expected =
    #|1:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "separator_field" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .separator_field_match(b"!!")
    .separator_field_context(b"^^")
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  let expected =
    #|sherlock!!For the Doctor Watsons of this world, as opposed to the Sherlock
    #|sherlock^^Holmeses, success in the province of detective work must always
    #|--
    #|sherlock^^can extract a clew from a wisp of straw or a flake of cigar ash;
    #|sherlock!!but Doctor Watson has to have it taken out for him and dusted,
    #|sherlock^^and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "separator_path" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .separator_path(Some(b'Z'))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "books/sherlock"),
  )
  let got = contents(out)
  let expected =
    #|booksZsherlock:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|booksZsherlock:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "path_terminator" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .path_terminator(Some(b'Z'))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "books/sherlock"),
  )
  let got = contents(out)
  let expected =
    #|books/sherlockZFor the Doctor Watsons of this world, as opposed to the Sherlock
    #|books/sherlockZbut Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "heading" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .heading(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  let expected =
    #|sherlock
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "no_heading" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .heading(false)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  let expected =
    #|sherlock:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|sherlock:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "no_heading_multiple" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .heading(false)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  let expected =
    #|sherlock:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|sherlock:but Doctor Watson has to have it taken out for him and dusted,
    #|sherlock:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|sherlock:be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(got, expected)
}

///|
async test "heading_multiple" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .heading(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(
    matcher,
    reader(str_bytes(sherlock)),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  let expected =
    #|sherlock
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|sherlock
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(got, expected)
}

///|
async test "trim_ascii" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .trim_ascii(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes("   Watson")), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|Watson
    #|
  assert_eq(got, expected)
}

///|
async test "trim_ascii_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s:.{0})Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .trim_ascii(true)
    .stats(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .build()
  .search_reader(matcher, reader(str_bytes("   Watson")), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|Watson
    #|
  assert_eq(got, expected)
}

///|
async test "trim_ascii_with_line_term" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .trim_ascii(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .before_context(1)
  .build()
  .search_reader(
    matcher,
    reader(
      str_bytes(
        (
          #|
          #|   Watson
        ),
      ),
    ),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected =
    #|1-
    #|2:Watson
    #|
  assert_eq(got, expected)
}

///|
async test "line_number" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "line_number_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .multi_line(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|2:Holmeses, success in the province of detective work must always
    #|3:be, to a very large extent, the result of luck. Sherlock Holmes
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "column_number" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|16:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|12:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "column_number_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|16:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|16:Holmeses, success in the province of detective work must always
    #|16:be, to a very large extent, the result of luck. Sherlock Holmes
    #|16:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|16:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "byte_offset" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .byte_offset(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|0:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|258:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "byte_offset_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .byte_offset(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|0:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|65:Holmeses, success in the province of detective work must always
    #|129:be, to a very large extent, the result of luck. Sherlock Holmes
    #|193:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|258:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns" {
  let matcher = @grep_regex.RegexMatcher::new("ash|dusted")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .max_columns(Some(63))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|[Omitted long matching line]
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_preview" {
  let matcher = @grep_regex.RegexMatcher::new("exhibited|dusted")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .max_columns(Some(46))
    .max_columns_preview(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|but Doctor Watson has to have it taken out for [... omitted end of long line]
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_with_count" {
  let matcher = @grep_regex.RegexMatcher::new("cigar|ash|dusted")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .max_columns(Some(63))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|[Omitted long line with 2 matches]
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_with_count_preview_no_match" {
  let matcher = @grep_regex.RegexMatcher::new("exhibited|has to have it")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .max_columns(Some(46))
    .max_columns_preview(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|but Doctor Watson has to have it taken out for [... 0 more matches]
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_with_count_preview_one_match" {
  let matcher = @grep_regex.RegexMatcher::new("exhibited|dusted")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .max_columns(Some(46))
    .max_columns_preview(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|but Doctor Watson has to have it taken out for [... 1 more match]
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_with_count_preview_two_matches" {
  let matcher = @grep_regex.RegexMatcher::new("exhibited|dusted|has to have it")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .max_columns(Some(46))
    .max_columns_preview(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|but Doctor Watson has to have it taken out for [... 1 more match]
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)ash.+dusted")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .max_columns(Some(63))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|[Omitted long matching line]
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "max_columns_multi_line_preview" {
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s)clew|cigar ash.+have it|exhibited",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .stats(true)
    .max_columns(Some(46))
    .max_columns_preview(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|can extract a clew from a wisp of straw or a f [... 1 more match]
    #|but Doctor Watson has to have it taken out for [... 0 more matches]
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches_context" {
  // after context: 1
  let matcher = @grep_regex.RegexMatcher::new("Doctor Watsons")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .max_matches(Some(1))
  .line_number(false)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|
  assert_eq(got, expected)
  let out = @termcolor.ByteVec::new()
  // after context: 4
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .max_matches(Some(1))
  .line_number(false)
  .after_context(4)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|be, to a very large extent, the result of luck. Sherlock Holmes
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
  // after context: 1, max matches: 2
  let matcher = @grep_regex.RegexMatcher::new("Doctor Watsons|but Doctor")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .max_matches(Some(2))
  .line_number(false)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
  let out = @termcolor.ByteVec::new()
  // after context: 4, max matches: 2
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .max_matches(Some(2))
  .line_number(false)
  .after_context(4)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|be, to a very large extent, the result of luck. Sherlock Holmes
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches_context_invert" {
  // after context: 1
  let matcher = @grep_regex.RegexMatcher::new(
    "success|extent|clew|dusted|exhibited",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .invert_match(true)
  .max_matches(Some(1))
  .line_number(false)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|
  assert_eq(got, expected)
  let out = @termcolor.ByteVec::new()
  // after context: 4
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .invert_match(true)
  .max_matches(Some(1))
  .line_number(false)
  .after_context(4)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|be, to a very large extent, the result of luck. Sherlock Holmes
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
  // after context: 1, max matches: 2
  let matcher = @grep_regex.RegexMatcher::new("success|extent|clew|exhibited")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .invert_match(true)
  .max_matches(Some(2))
  .line_number(false)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|--
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
  let out = @termcolor.ByteVec::new()
  // after context: 4, max matches: 2
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .invert_match(true)
  .max_matches(Some(2))
  .line_number(false)
  .after_context(4)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|be, to a very large extent, the result of luck. Sherlock Holmes
    #|can extract a clew from a wisp of straw or a flake of cigar ash;
    #|but Doctor Watson has to have it taken out for him and dusted,
    #|and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches_multi_line1" {
  let matcher = @grep_regex.RegexMatcher::new("(?s:.{0})Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches_multi_line2" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+?(Holmeses|clearly)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|For the Doctor Watsons of this world, as opposed to the Sherlock
    #|Holmeses, success in the province of detective work must always
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches_multi_line3" {
  let matcher = @grep_regex.RegexMatcher::new("line 2\\nline 3")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .max_matches(Some(1))
  .build()
  .search_reader(
    matcher,
    reader(
      str_bytes(
        (
          #|line 2
          #|line 3 x
          #|line 2
          #|line 3
          #|
        ),
      ),
    ),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected =
    #|line 2
    #|line 3 x
    #|
  assert_eq(got, expected)
}

///|
async test "max_matches_multi_line4" {
  let matcher = @grep_regex.RegexMatcher::new("line 2\\nline 3|x\\nline 2\\n")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .multi_line(true)
  .max_matches(Some(1))
  .build()
  .search_reader(
    matcher,
    reader(
      str_bytes(
        (
          #|line 2
          #|line 3 x
          #|line 2
          #|line 3 x
          #|
        ),
      ),
    ),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected =
    #|line 2
    #|line 3 x
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching" {
  let matcher = @grep_regex.RegexMatcher::new("Doctor Watsons|Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:Doctor Watsons
    #|1:57:Sherlock
    #|3:49:Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_multi_line1" {
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s:.{0})(Doctor Watsons|Sherlock)",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:Doctor Watsons
    #|1:57:Sherlock
    #|3:49:Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_multi_line2" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+?(Holmeses|clearly)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:Watsons of this world, as opposed to the Sherlock
    #|2:16:Holmeses
    #|5:12:Watson has to have it taken out for him and dusted,
    #|6:12:and exhibited clearly
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_max_columns" {
  let matcher = @grep_regex.RegexMatcher::new("Doctor Watsons|Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .max_columns(Some(10))
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:[Omitted long matching line]
    #|1:57:Sherlock
    #|3:49:Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_max_columns_preview" {
  let matcher = @grep_regex.RegexMatcher::new("Doctor Watsons|Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .max_columns(Some(10))
    .max_columns_preview(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:Doctor Wat [... 0 more matches]
    #|1:57:Sherlock
    #|3:49:Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_max_columns_multi_line1" {
  // The `(?s:.{0})` trick fools the matcher into thinking that it
  // can match across multiple lines without actually doing so. This is
  // so we can test multi-line handling in the case of a match on only
  // one line.
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s:.{0})(Doctor Watsons|Sherlock)",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .max_columns(Some(10))
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:[Omitted long matching line]
    #|1:57:Sherlock
    #|3:49:Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_max_columns_preview_multi_line1" {
  // The `(?s:.{0})` trick fools the matcher into thinking that it
  // can match across multiple lines without actually doing so. This is
  // so we can test multi-line handling in the case of a match on only
  // one line.
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s:.{0})(Doctor Watsons|Sherlock)",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .max_columns(Some(10))
    .max_columns_preview(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:Doctor Wat [... 0 more matches]
    #|1:57:Sherlock
    #|3:49:Sherlock
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_max_columns_multi_line2" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+?(Holmeses|clearly)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .max_columns(Some(50))
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:Watsons of this world, as opposed to the Sherlock
    #|2:16:Holmeses
    #|5:12:[Omitted long matching line]
    #|6:12:and exhibited clearly
    #|
  assert_eq(got, expected)
}

///|
async test "only_matching_max_columns_preview_multi_line2" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+?(Holmeses|clearly)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .max_columns(Some(50))
    .max_columns_preview(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:Watsons of this world, as opposed to the Sherlock
    #|2:16:Holmeses
    #|5:12:Watson has to have it taken out for him and dusted [... 0 more matches]
    #|6:12:and exhibited clearly
    #|
  assert_eq(got, expected)
}

///|
async test "per_match" {
  let matcher = @grep_regex.RegexMatcher::new("Doctor Watsons|Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|1:57:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|3:49:be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(got, expected)
}

///|
async test "per_match_multi_line1" {
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s:.{0})(Doctor Watsons|Sherlock)",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|1:57:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|3:49:be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(got, expected)
}

///|
async test "per_match_multi_line2" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+?(Holmeses|clearly)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|2:1:Holmeses, success in the province of detective work must always
    #|5:12:but Doctor Watson has to have it taken out for him and dusted,
    #|6:1:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "per_match_multi_line3" {
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s)Watson.+?Holmeses|always.+?be",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|2:1:Holmeses, success in the province of detective work must always
    #|2:58:Holmeses, success in the province of detective work must always
    #|3:1:be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(got, expected)
}

///|
async test "per_match_multi_line1_only_first_line" {
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s:.{0})(Doctor Watsons|Sherlock)",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .per_match_one_line(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:9:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|1:57:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|3:49:be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(got, expected)
}

///|
async test "per_match_multi_line2_only_first_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s)Watson.+?(Holmeses|clearly)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .per_match_one_line(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|5:12:but Doctor Watson has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "per_match_multi_line3_only_first_line" {
  let matcher = @grep_regex.RegexMatcher::new(
    "(?s)Watson.+?Holmeses|always.+?be",
  )
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .per_match_one_line(true)
    .column(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:16:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|2:58:Holmeses, success in the province of detective work must always
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_passthru" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|Doctor (\\w+)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .replacement(Some(b"doctah $1 MD"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .passthru(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:For the doctah Watsons MD of this world, as opposed to the doctah  MD
    #|2-Holmeses, success in the province of detective work must always
    #|3:be, to a very large extent, the result of luck. doctah  MD Holmes
    #|4-can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but doctah Watson MD has to have it taken out for him and dusted,
    #|6-and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "replacement" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|Doctor (\\w+)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .replacement(Some(b"doctah $1 MD"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:For the doctah Watsons MD of this world, as opposed to the doctah  MD
    #|3:be, to a very large extent, the result of luck. doctah  MD Holmes
    #|5:but doctah Watson MD has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("\\n")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .replacement(Some(b"?"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .multi_line(true)
  .build()
  .search_reader(
    matcher,
    reader(
      str_bytes(
        (
          #|hello
          #|world
          #|
        ),
      ),
    ),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected =
    #|1:hello?world?
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_multi_line_diff_line_term" {
  let matcher = @grep_regex.RegexMatcherBuilder::new()
    .line_terminator(Some(b'\x00'))
    .build("\\n")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .replacement(Some(b"?"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_terminator(@matcher.LineTerminator::byte(b'\x00'))
  .line_number(true)
  .multi_line(true)
  .build()
  .search_reader(
    matcher,
    reader(
      str_bytes(
        (
          #|hello
          #|world
          #|
        ),
      ),
    ),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected = "1:hello?world?\u{0}"
  assert_eq(got, expected)
}

///|
async test "replacement_multi_line_combine_lines" {
  let matcher = @grep_regex.RegexMatcher::new("\\n(.)?")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .replacement(Some(b"?$1"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .multi_line(true)
  .build()
  .search_reader(
    matcher,
    reader(
      str_bytes(
        (
          #|hello
          #|world
          #|
        ),
      ),
    ),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected =
    #|1:hello?world?
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_max_columns" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|Doctor (\\w+)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .max_columns(Some(67))
    .replacement(Some(b"doctah $1 MD"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:[Omitted long line with 2 matches]
    #|3:be, to a very large extent, the result of luck. doctah  MD Holmes
    #|5:but doctah Watson MD has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_max_columns_preview1" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|Doctor (\\w+)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .max_columns(Some(67))
    .max_columns_preview(true)
    .replacement(Some(b"doctah $1 MD"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:For the doctah Watsons MD of this world, as opposed to the doctah   [... 0 more matches]
    #|3:be, to a very large extent, the result of luck. doctah  MD Holmes
    #|5:but doctah Watson MD has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_max_columns_preview2" {
  let matcher = @grep_regex.RegexMatcher::new("exhibited|dusted|has to have it")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .max_columns(Some(43))
    .max_columns_preview(true)
    .replacement(Some(b"xxx"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(false)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|but Doctor Watson xxx taken out for him and [... 1 more match]
    #|and xxx clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_only_matching" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|Doctor (\\w+)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .replacement(Some(b"doctah $1 MD"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:doctah Watsons MD
    #|1:doctah  MD
    #|3:doctah  MD
    #|5:doctah Watson MD
    #|
  assert_eq(got, expected)
}

///|
async test "replacement_per_match" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock|Doctor (\\w+)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .per_match(true)
    .replacement(Some(b"doctah $1 MD"))
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1:For the doctah Watsons MD of this world, as opposed to the doctah  MD
    #|1:For the doctah Watsons MD of this world, as opposed to the doctah  MD
    #|3:be, to a very large extent, the result of luck. doctah  MD Holmes
    #|5:but doctah Watson MD has to have it taken out for him and dusted,
    #|
  assert_eq(got, expected)
}

///|
async test "invert" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .invert_match(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|2:Holmeses, success in the province of detective work must always
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|6:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "invert_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s:.{0})Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .invert_match(true)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|2:Holmeses, success in the province of detective work must always
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|6:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "invert_context" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .invert_match(true)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1-For the Doctor Watsons of this world, as opposed to the Sherlock
    #|2:Holmeses, success in the province of detective work must always
    #|3-be, to a very large extent, the result of luck. Sherlock Holmes
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|6:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "invert_context_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s:.{0})Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .invert_match(true)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1-For the Doctor Watsons of this world, as opposed to the Sherlock
    #|2:Holmeses, success in the province of detective work must always
    #|3-be, to a very large extent, the result of luck. Sherlock Holmes
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|6:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "invert_context_only_matching" {
  let matcher = @grep_regex.RegexMatcher::new("Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .line_number(true)
  .invert_match(true)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1-Sherlock
    #|2:Holmeses, success in the province of detective work must always
    #|3-Sherlock
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|6:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "invert_context_only_matching_multi_line" {
  let matcher = @grep_regex.RegexMatcher::new("(?s:.{0})Sherlock")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .only_matching(true)
    .build(@termcolor.NoColor::new(out))
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .line_number(true)
  .invert_match(true)
  .before_context(1)
  .after_context(1)
  .build()
  .search_reader(matcher, reader(str_bytes(sherlock)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|1-Sherlock
    #|2:Holmeses, success in the province of detective work must always
    #|3-Sherlock
    #|4:can extract a clew from a wisp of straw or a flake of cigar ash;
    #|5:but Doctor Watson has to have it taken out for him and dusted,
    #|6:and exhibited clearly, with a label attached.
    #|
  assert_eq(got, expected)
}

///|
async test "regression_search_empty_with_crlf" {
  let matcher = @grep_regex.RegexMatcherBuilder::new().crlf(true).build("x?")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .color_specs(@printer.ColorSpecs::default_with_color())
    .build(@termcolor.Ansi::new(out))
  @searcher.SearcherBuilder::new()
  .line_terminator(@matcher.LineTerminator::crlf())
  .build()
  .search_reader(matcher, reader(b"\n"), printer.sink(matcher))
  let got = contents(out)
  assert_false(got.is_empty())
}

///|
async test "regression_after_context_with_match" {
  let haystack =
    #|a
    #|b
    #|c
    #|d
    #|e
    #|d
    #|e
    #|d
    #|e
    #|d
    #|e
    #|
  let matcher = @grep_regex.RegexMatcherBuilder::new().build("d")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  @searcher.SearcherBuilder::new()
  .max_matches(Some(1))
  .line_number(true)
  .after_context(2)
  .build()
  .search_reader(matcher, reader(str_bytes(haystack)), printer.sink(matcher))
  let got = contents(out)
  let expected =
    #|4:d
    #|5-e
    #|6:d
    #|
  assert_eq(got, expected)
}

///|
async test "regression_crlf_preserve" {
  let haystack = "hello\nworld\r\n"
  let matcher = @grep_regex.RegexMatcherBuilder::new().crlf(true).build(".")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new().build(
    @termcolor.NoColor::new(out),
  )
  let searcher = @searcher.SearcherBuilder::new()
    .line_number(false)
    .line_terminator(@matcher.LineTerminator::crlf())
    .build()
  searcher.search_reader(
    matcher,
    reader(str_bytes(haystack)),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected = "hello\nworld\r\n"
  assert_eq(got, expected)
  let out = @termcolor.ByteVec::new()
  let printer = @printer.StandardBuilder::new()
    .replacement(Some(b"$0"))
    .build(@termcolor.NoColor::new(out))
  searcher.search_reader(
    matcher,
    reader(str_bytes(haystack)),
    printer.sink(matcher),
  )
  let got = contents(out)
  let expected = "hello\nworld\r\n"
  assert_eq(got, expected)
}
