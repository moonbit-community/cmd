///|
let json_sherlock : Bytes = b"For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached.\n"

///|
/// Splits like Rust's `str::lines` (a trailing newline does not produce
/// an empty final line).
fn rust_lines(s : String) -> Array[String] {
  let out = []
  let parts : Array[StringView] = s.split("\n").collect()
  for i, p in parts {
    if i == parts.length() - 1 && p.is_empty() {
      break
    }
    out.push(p.to_owned())
  }
  out
}

///|
async test "binary_detection" {
  let binary : Bytes = b"For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew \x00 from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached."
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .binary_detection(@searcher.BinaryDetection::BinaryQuit(b'\x00'))
  .heap_limit(Some(80))
  .build()
  .search_reader(matcher, reader(binary), printer.sink(matcher))
  let got = contents(out)
  let lines = rust_lines(got)
  assert_eq(lines.length(), 3)
  let last = lines[lines.length() - 1]
  assert_true(last.contains("\"binary_offset\":212,"))
}

///|
async test "max_matches" {
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(json_sherlock), printer.sink(matcher))
  let got = contents(out)
  assert_eq(rust_lines(got).length(), 3)
}

///|
async test "max_matches_after_context" {
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
  let matcher = @grep_regex.RegexMatcher::new("d")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .after_context(2)
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(str_bytes(haystack)), printer.sink(matcher))
  let got = contents(out)
  assert_eq(rust_lines(got).length(), 5)
}

///|
async test "no_match" {
  let matcher = @grep_regex.RegexMatcher::new("DOES NOT MATCH")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(matcher, reader(json_sherlock), printer.sink(matcher))
  let got = contents(out)
  assert_true(got.is_empty())
}

///|
async test "always_begin_end_no_match" {
  let matcher = @grep_regex.RegexMatcher::new("DOES NOT MATCH")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out, always_begin_end=true)
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(matcher, reader(json_sherlock), printer.sink(matcher))
  let got = contents(out)
  assert_eq(rust_lines(got).length(), 2)
  assert_true(got.contains("begin") && got.contains("end"))
}

///|
async test "missing_crlf" {
  let haystack = str_bytes("test\r\n")
  let matcher = @grep_regex.RegexMatcherBuilder::new().build("test")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(matcher, reader(haystack), printer.sink(matcher))
  let got = contents(out)
  assert_eq(rust_lines(got).length(), 3)
  assert_true(rust_lines(got)[1].contains("test\\r\\n"))
  let matcher = @grep_regex.RegexMatcherBuilder::new().crlf(true).build("test")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .line_terminator(@matcher.LineTerminator::crlf())
  .build()
  .search_reader(matcher, reader(haystack), printer.sink(matcher))
  let got = contents(out)
  assert_eq(rust_lines(got).length(), 3)
  assert_true(rust_lines(got)[1].contains("test\\r\\n"))
}

///|
async test "non_utf8_path" {
  // A file name that isn't valid UTF-8 (as decoded by `sys`) is written as
  // base64 bytes, like ripgrep's `json::notutf8` test expects.
  let matcher = @grep_regex.RegexMatcher::new("Watson")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  let path = @osstr.decode(b"foo\xFFbar")
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(json_sherlock),
    printer.sink_with_path(matcher, path),
  )
  let lines = rust_lines(contents(out))
  assert_eq(
    lines[0],
    "{\"type\":\"begin\",\"data\":{\"path\":{\"bytes\":\"Zm9v/2Jhcg==\"}}}",
  )
}

///|
async test "multi_line_max_matches_keeps_submatches_within_lines" {
  // A multi-line match truncated by the match limit: submatches past the
  // reported lines are clipped or dropped (ripgrep 15.2.0 panics here).
  let matcher = @grep_regex.RegexMatcherBuilder::new()
    .multi_line(true)
    .build("(?s:.*)")
  let out = @termcolor.ByteVec::new()
  let printer = @printer.JSON::new(out)
  @searcher.SearcherBuilder::new()
  .multi_line(true)
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(b"a\xFF\nb\n"), printer.sink(matcher))
  let lines = rust_lines(contents(out))
  assert_true(lines[1].contains("\"lines\":{\"bytes\":\"Yf8K\"}"))
  assert_true(lines[1].contains("\"start\":2,\"end\":3}]"))
}
