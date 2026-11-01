///|
/// Independent whole-buffer oracle for the streamed window. A trailing
/// newline terminates the final line rather than starting an empty one.
fn select_lines(
  data : Bytes,
  spec : CountSpec,
  delimiter~ : Byte = b'\n',
) -> BytesView {
  match spec {
    Last(n) => {
      if n <= 0 || data.length() == 0 {
        return data[0:0]
      }
      let mut i = if data[data.length() - 1] == delimiter {
        data.length() - 2
      } else {
        data.length() - 1
      }
      let mut newlines : Int64 = 0
      while i >= 0 {
        if data[i] == delimiter {
          newlines += 1
          if newlines == n {
            return data[i + 1:]
          }
        }
        i -= 1
      }
      data
    }
    FromStart(k) => {
      if k <= 1 {
        return data
      }
      let mut seen : Int64 = 0
      for i in 0..<data.length() {
        if data[i] == delimiter {
          seen += 1
          if seen == k - 1 {
            return data[i + 1:]
          }
        }
      }
      data[data.length():]
    }
  }
}

///|
fn select_bytes(data : Bytes, spec : CountSpec) -> BytesView {
  let len = data.length().to_int64()
  match spec {
    Last(n) => {
      let start = if n >= len { 0 } else { (len - n).to_int() }
      data[start:]
    }
    FromStart(k) => {
      let start = if k - 1 > len { data.length() } else { (k - 1).to_int() }
      data[start:]
    }
  }
}

///|
fn window_bytes(window : TailWindow) -> Bytes {
  let output = @buffer.Buffer()
  for chunk in window.chunks.iter() {
    output.write_bytes(chunk.data[chunk.start:])
  }
  output.to_bytes()
}

///|
test "tail window releases a discarded long line before a tiny final record" {
  let window = TailWindow::new()
  for _ in 0..<8 {
    window.push(Bytes::make(65536, b'a'), 1L, false, b'\n')
  }
  window.push(b"\nx", 1L, false, b'\n')
  assert_eq(window_bytes(window), b"x")
  assert_eq(window.bytes, 1L)
  assert_eq(window.chunks.length(), 1)
  assert_eq(window.chunks[0].data.length(), 2)
}

///|
test "tail window agrees with independent selection at every fragmented prefix" {
  for
    data in [
      b"a\nb\nc\n", b"a\nb\nc", b"\n\n\n", b"a\x00bb\x00c", b"abcdef", b"a\nb\nc\nd\ne\n",
    ] {
    for delimiter in [b'\n', b'\x00'] {
      for count in [1L, 2L, 10L, 9223372036854775807L] {
        for bytes_mode in [false, true] {
          for width in [1, 2, 7, 65536] {
            let window = TailWindow::new()
            for start = 0; start < data.length(); start = start + width {
              let end = (start + width).min(data.length())
              window.push(
                data[start:end].to_owned(),
                count,
                bytes_mode,
                delimiter,
              )
              let prefix = data[:end].to_owned()
              let expected = if bytes_mode {
                select_bytes(prefix, Last(count))
              } else {
                select_lines(prefix, Last(count), delimiter~)
              }
              assert_eq(window_bytes(window), expected.to_owned())
              assert_eq(window.bytes, expected.length().to_int64())
            }
          }
        }
      }
    }
  }
}
