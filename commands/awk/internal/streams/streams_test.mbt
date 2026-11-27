///|
test "An explicit dash continues the same staged stdin" {
  let host = @streams.Host::new()
  host.stage_stdin(b"abc")
  assert_true(host.input(Open("-")) is Ready)
  assert_true(host.input(Read) is Chunk("abc"))
  assert_true(host.input(Close) is Ready)
  assert_true(host.input(Open("-")) is Ready)
  assert_true(host.input(Read) is End)
  assert_true(host.input(Close) is Ready)
}
