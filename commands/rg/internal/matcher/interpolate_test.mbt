///|
fn interp(
  map : Array[(String, Int32)],
  caps : Array[String],
  rep : String,
) -> String {
  let dst = Buffer()
  @matcher.interpolate(
    @utf8.encode(rep),
    (i, dst) => if i < caps.length() { dst.write_bytes(@utf8.encode(caps[i])) },
    name => {
      for x in map {
        if x.0 == name {
          return Some(x.1)
        }
      }
      None
    },
    dst,
  )
  @utf8.decode_lossy(dst.to_bytes())
}

///|
test "interpolate" {
  inspect(
    interp([("foo", 2)], ["", "", "xxx"], "test $foo test"),
    content="test xxx test",
  )
  inspect(interp([("foo", 2)], ["", "", "xxx"], "test$footest"), content="test")
  inspect(
    interp([("foo", 2)], ["", "", "xxx"], "test${foo}test"),
    content="testxxxtest",
  )
  inspect(interp([("foo", 2)], ["", "", "xxx"], "test$2test"), content="test")
  inspect(
    interp([("foo", 2)], ["", "", "xxx"], "test${2}test"),
    content="testxxxtest",
  )
  inspect(
    interp([("foo", 2)], ["", "", "xxx"], "test $$foo test"),
    content="test $foo test",
  )
  inspect(
    interp([("foo", 2)], ["", "", "xxx"], "test $foo"),
    content="test xxx",
  )
  inspect(
    interp([("foo", 2)], ["", "", "xxx"], "$foo test"),
    content="xxx test",
  )
  inspect(
    interp([("bar", 1), ("foo", 2)], ["", "yyy", "xxx"], "test $bar$foo"),
    content="test yyyxxx",
  )
  inspect(
    interp([("bar", 1), ("foo", 2)], ["", "yyy", "xxx"], "test $ test"),
    content="test $ test",
  )
  inspect(
    interp([("bar", 1), ("foo", 2)], ["", "yyy", "xxx"], "test ${} test"),
    content="test ${} test",
  )
  inspect(
    interp([("bar", 1), ("foo", 2)], ["", "yyy", "xxx"], "test ${ } test"),
    content="test ${ } test",
  )
  inspect(
    interp([("bar", 1), ("foo", 2)], ["", "yyy", "xxx"], "test ${a b} test"),
    content="test ${a b} test",
  )
  inspect(
    interp([("bar", 1), ("foo", 2)], ["", "yyy", "xxx"], "test ${a} test"),
    content="test  test",
  )
}
