///|
test "cp overwrite flags are absent by default" {
  let parsed = @cli.parse(["source", "destination"], [
    @cli.flag("force", short='f'),
    @cli.flag("no-clobber", short='n'),
    @cli.flag("interactive", short='i'),
  ]) catch {
    _ => fail("parse failed")
  }
  assert_eq(
    parsed.last_occurrence(["force", "no-clobber", "interactive"]),
    None,
  )
  assert_false(parsed.contains("interactive"))
}
