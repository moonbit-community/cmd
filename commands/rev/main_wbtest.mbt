///|
test "rev reverses bytes within each line and preserves newlines" {
  assert_eq(reverse_lines(b"abc\n123\n"), b"cba\n321\n")
  assert_eq(reverse_lines(b"abc\n123"), b"cba\n321")
}

///|
test "rev is byte oriented for invalid UTF-8" {
  assert_eq(reverse_lines(b"a\xc3\xa9\n"), b"\xa9\xc3a\n")
}

///|
async test "rev rejects invalid C records before output and continues later readers" {
  let observations : Array[(Int64, Bool)] = []
  let output = @io.MemoryReader(writer => {
    for data in [b"ok\nab\xffcd\nignored\n", b"bad\x80", b"tail\x00"] {
      let reader = @io.MemoryReader(input => input.write(data))
      defer reader.close()
      let count = Ref(0L)
      let rejected = try {
        reverse_reader(reader, count, writer~)
        false
      } catch {
        InvalidCRecord as error => {
          assert_eq(
            error_message(error),
            "Invalid or incomplete multibyte or wide character",
          )
          true
        }
        error => raise error
      }
      observations.push((count.val, rejected))
    }
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"ko\n\x00liat")
  assert_eq(observations, [(1L, true), (0L, true), (1L, false)])
}
