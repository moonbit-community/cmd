///|
test "od duplicate rows and skip limit preserve absolute address" {
  let state = settings(
    @cli.parse(["-t", "x1", "-j", "2", "-N", "4", "-w4"], [
      @cli.option("format", short='t'),
      @cli.option("skip-bytes", short='j'),
      @cli.option("read-bytes", short='N'),
      @cli.option("width", short='w'),
    ]),
  )
  assert_eq(state.feed(b"xxab"), "")
  assert_eq(state.feed(b"cdyz"), "0000002 61 62 63 64\n")
  assert_eq(state.offset, 6L)
  assert_eq(state.remaining, Some(0L))
  let repeated = settings(
    @cli.parse(["-t", "x1", "-w4"], [
      @cli.option("format", short='t'),
      @cli.option("width", short='w'),
    ]),
  )
  assert_eq(repeated.feed(b"abcdabcdabcd"), "0000000 61 62 63 64\n*\n")
  assert_eq(repeated.offset, 12L)
}
