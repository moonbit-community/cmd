///|
async fn scan_strings(
  data : Bytes,
  minimum : Int32,
  eight_bit~ : Bool = false,
  prefix~ : Bool = false,
  radix~ : Int32? = None,
  separator~ : String = "\n",
) -> Bytes {
  let input = @io.MemoryReader(writer => writer.write(data))
  defer input.close()
  let output = @io.MemoryReader(writer => {
    emit_stream(
      input,
      writer,
      "-",
      minimum,
      prefix,
      radix,
      eight_bit,
      separator~,
    )
  })
  defer output.close()
  output.read_all().binary()
}

///|
async test "strings custom separator preserves accepted final and empty runs" {
  assert_eq(scan_strings(b"abc\x00def\x00no", 3, separator="<>"), b"abc<>def<>")
  assert_eq(scan_strings(b"abc\x00def", 3, separator=""), b"abcdef")
  assert_eq(scan_strings(b"ab\x00", 3, separator="<>"), b"")
  assert_eq(
    scan_strings(b"abc", 3, prefix=true, radix=Some(10), separator="|"),
    b"{standard input}:       0 abc|",
  )
}

///|
async test "strings keeps printable runs and minimum length" {
  assert_eq(scan_strings(b"xxhello\x00world\nno", 4), b"xxhello\nworld\n")
  assert_eq(scan_strings(b"ab\tcd\x00\xffabcd", 4), b"ab\tcd\nabcd\n")
  assert_eq(scan_strings(b"ab\xffcd\x00", 4, eight_bit=true), b"ab\xffcd\n")
  assert_eq(scan_strings(b"", 4), b"")
}

///|
async test "strings crosses chunks and streams long printable runs" {
  let text = "x".repeat(65533) +
    "\u0000abcdef\u0000short\u0000" +
    "z".repeat(131073)
  let data : &@io.Data = text
  let expected : &@io.Data = "{standard input}:       0 " +
    "x".repeat(65533) +
    "\n{standard input}:   65534 abcdef\n{standard input}:   65547 " +
    "z".repeat(131073) +
    "\n"
  assert_eq(
    scan_strings(data.binary(), 6, prefix=true, radix=Some(10)),
    expected.binary(),
  )
  assert_eq(scan_strings(b"abcdef", 7), b"")
}

///|
test "strings formats requested radix" {
  assert_eq(radix_string(10, 2), "1010")
  assert_eq(radix_string(10, 8), "12")
  assert_eq(radix_string(10, 16), "a")
  assert_eq(parse_radix("x"), Some(16))
  assert_eq(parse_radix("d"), Some(10))
  assert_eq(parse_radix("b"), None)
  assert_eq(radix_string(4294967296, 16), "100000000")
}

///|
priv suberror StringsInputError {
  StringsInputError
}

///|
async test "strings retains completed output before a producer error" {
  for (bytes, expected) in [(b"abcdef", b"abcdef\nerror"), (b"ab", b"error")] {
    let input = @io.MemoryReader(writer => {
      writer.write(bytes)
      @async.sleep(1)
      raise StringsInputError
    })
    defer input.close()
    let output = @io.MemoryReader(writer => {
      emit_stream(input, writer, "-", 4, false, None, false) catch {
        StringsInputError => writer.write("error")
        error => raise error
      }
    })
    defer output.close()
    assert_eq(output.read_all().binary(), expected)
  }
}
