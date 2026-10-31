///|
let sherlock_lib : String =
  #|For the Doctor Watsons of this world, as opposed to the Sherlock
  #|Holmeses, success in the province of detective work must always
  #|be, to a very large extent, the result of luck. Sherlock Holmes
  #|can extract a clew from a wisp of straw or a flake of cigar ash;
  #|but Doctor Watson has to have it taken out for him and dusted,
  #|and exhibited clearly, with a label attached.
  #|

///|
/// The crate-level example from grep-printer's lib.rs.
async test "lib example" {
  let matcher = SearchMatcher::new(["Sherlock"])
  let out = @termcolor.ByteVec::new()
  let printer = @printer.Standard::new_no_color(out)
  @searcher.Searcher::new().search_bytes(
    matcher,
    @utf8.encode(sherlock_lib),
    printer.sink(matcher),
  )
  let expected =
    #|1:For the Doctor Watsons of this world, as opposed to the Sherlock
    #|3:be, to a very large extent, the result of luck. Sherlock Holmes
    #|
  assert_eq(@utf8.decode_lossy(out.to_bytes()), expected)
}
