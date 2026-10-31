///|
/// Note that unlike the standard printer tests, this one has a trailing
/// line terminator (as in the Rust source).
let summary_sherlock : Bytes = b"For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached.\n"

///|
async test "path_with_match_error" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::PathWithMatch,
  )
  let res = try
    @searcher.SearcherBuilder::new()
    .build()
    .search_reader(matcher, reader(summary_sherlock), printer.sink(matcher))
  catch {
    e => Err(e.to_string())
  } noraise {
    _ => Ok(())
  }
  assert_eq(res, Err("output kind PathWithMatch requires a file path"))
}

///|
async test "path_without_match_error" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::PathWithoutMatch,
  )
  let res = try
    @searcher.SearcherBuilder::new()
    .build()
    .search_reader(matcher, reader(summary_sherlock), printer.sink(matcher))
  catch {
    e => Err(e.to_string())
  } noraise {
    _ => Ok(())
  }
  assert_eq(res, Err("output kind PathWithoutMatch requires a file path"))
}

///|
async test "count_no_path" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(matcher, reader(summary_sherlock), printer.sink(matcher))
  let got = contents(out)
  assert_eq(
    got,
    (
      #|2
      #|
    ),
  )
}

///|
async test "count_no_path_even_with_path" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
    path=false,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|2
      #|
    ),
  )
}

///|
async test "count_path" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|sherlock:2
      #|
    ),
  )
}

///|
async test "count_path_with_zero" {
  let matcher = SearchMatcher::new(["NO MATCH"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
    exclude_zero=false,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|sherlock:0
      #|
    ),
  )
}

///|
async test "count_path_without_zero" {
  let matcher = SearchMatcher::new(["NO MATCH"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
    exclude_zero=true,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(got, "")
}

///|
async test "count_path_field_separator" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
    separator_field=b"ZZ",
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|sherlockZZ2
      #|
    ),
  )
}

///|
async test "count_path_terminator" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
    path_terminator=Some(b'\x00'),
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(got, "sherlock\u{0}2\n")
}

///|
async test "count_path_separator" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
    separator_path=Some(b'\\'),
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "/home/andrew/sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|\home\andrew\sherlock:2
      #|
    ),
  )
}

///|
async test "count_max_matches" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::Count,
  )
  @searcher.SearcherBuilder::new()
  .max_matches(Some(1))
  .build()
  .search_reader(matcher, reader(summary_sherlock), printer.sink(matcher))
  let got = contents(out)
  assert_eq(
    got,
    (
      #|1
      #|
    ),
  )
}

///|
async test "count_matches" {
  let matcher = SearchMatcher::new(["Watson|Sherlock"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::CountMatches,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|sherlock:4
      #|
    ),
  )
}

///|
async test "path_with_match_found" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::PathWithMatch,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|sherlock
      #|
    ),
  )
}

///|
async test "path_with_match_not_found" {
  let matcher = SearchMatcher::new(["ZZZZZZZZ"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::PathWithMatch,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(got, "")
}

///|
async test "path_without_match_found" {
  let matcher = SearchMatcher::new(["ZZZZZZZZZ"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::PathWithoutMatch,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(
    got,
    (
      #|sherlock
      #|
    ),
  )
}

///|
async test "path_without_match_not_found" {
  let matcher = SearchMatcher::new(["Watson"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::PathWithoutMatch,
  )
  @searcher.SearcherBuilder::new()
  .build()
  .search_reader(
    matcher,
    reader(summary_sherlock),
    printer.sink_with_path(matcher, "sherlock"),
  )
  let got = contents(out)
  assert_eq(got, "")
}

///|
async test "quiet" {
  let matcher = SearchMatcher::new(["Watson|Sherlock"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::QuietWithMatch,
  )
  let match_count = {
    let sink = printer.sink_with_path(matcher, "sherlock")
    @searcher.SearcherBuilder::new()
    .build()
    .search_reader(matcher, reader(summary_sherlock), sink)
    sink.match_count()
  }
  let got = contents(out)
  assert_eq(got, "")
  // There is actually more than one match, but Quiet should quit after
  // finding the first one.
  assert_eq(1L, match_count)
}

///|
async test "quiet_with_stats" {
  let matcher = SearchMatcher::new(["Watson|Sherlock"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Summary::new(
    @termcolor.NoColor::new(out),
    kind=@printer.SummaryKind::QuietWithMatch,
    stats=true,
  )
  let match_count = {
    let sink = printer.sink_with_path(matcher, "sherlock")
    @searcher.SearcherBuilder::new()
    .build()
    .search_reader(matcher, reader(summary_sherlock), sink)
    sink.match_count()
  }
  let got = contents(out)
  assert_eq(got, "")
  // There is actually more than one match, and Quiet will usually quit
  // after finding the first one, but since we request stats, it will
  // mush on to find all matches.
  assert_eq(3L, match_count)
}
