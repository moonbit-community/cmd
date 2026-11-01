///|
async test "jq chunk scanning preserves every JSON framing boundary" {
  let source = @utf8.encode(
    " \t1{\"x\":[\"界\\\"}\\\\\",true,null]}[2]\"尾\" false\n-1.5e2 ",
  )
  let expected = [
    @json.parse("1"),
    @json.parse("{\"x\":[\"界\\\"}\\\\\",true,null]}"),
    @json.parse("[2]"),
    Json::string("尾"),
    @json.parse("false"),
    @json.parse("-1.5e2"),
  ]
  for chunk in [1, 2, 3, 7, 17, 65536] {
    let reader = @io.MemoryReader(writer => {
      for i = 0; i < source.length(); i = i + chunk {
        writer.write(source[i:(i + chunk).min(source.length())])
      }
    })
    defer reader.close()
    let input = JsonInput::new(reader)
    let actual : Array[Json] = []
    while input.next() is Some(value) {
      actual.push(value)
    }
    assert_eq(actual, expected)
  }
  for text in ["{\"a\":", "[1,", "\"unterminated", "tru", "[}"] {
    let reader = @io.MemoryReader(writer => writer.write(text))
    defer reader.close()
    let input = JsonInput::new(reader)
    assert_true(
      try {
        ignore(input.next())
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
async test "jq completed frame is returned before later input is requested" {
  let reader = @io.MemoryReader(writer => {
    writer.write("[1]")
    writer.write("unread")
    fail("later input failure")
  })
  defer reader.close()
  assert_eq(JsonInput::new(reader).next(), Some(@json.parse("[1]")))
}
