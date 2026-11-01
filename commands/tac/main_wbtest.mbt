///|
async fn reversed(
  data : Bytes,
  separator : Bytes,
  before : Bool,
  regex~ : @bytere.Pattern? = None,
  size~ : Int32 = 3,
) -> Bytes {
  let root = @fs.tmpdir(prefix="cli-tac-test-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fs.open(
    root + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  file.write(data)
  let output = @io.MemoryReader(writer => {
    match regex {
      None => reverse_file(file, separator, before, writer~, size~)
      Some(pattern) => reverse_regex(file, pattern, before, writer)
    }
  })
  defer output.close()
  output.read_all().binary()
}

///|
fn reversed_byte_oracle(data : Bytes, separator : Byte, before : Bool) -> Bytes {
  let records : Array[BytesView] = []
  let mut start = 0
  for index, byte in data {
    if byte == separator {
      let end = index + (if before { 0 } else { 1 })
      records.push(data[start:end])
      start = end
    }
  }
  records.push(data[start:])
  let output = @buffer.Buffer()
  for index = records.length() - 1; index >= 0; index = index - 1 {
    output.write_bytes(records[index])
  }
  output.to_bytes()
}

///|
async test "tac byte batches agree with forward partitions across arbitrary small blocks" {
  for separator in [b'\n', b'\x00'] {
    for number in 0..<64 {
      let data = Bytes::makei(6, index => {
        if (number & (1 << index)) == 0 {
          b'a'
        } else {
          separator
        }
      })
      for before in [false, true] {
        assert_eq(
          reversed(data, Bytes::from_array([separator]), before),
          reversed_byte_oracle(data, separator, before),
        )
      }
    }
    for length in [65535, 65536, 65537, 131073] {
      let data = b"head" +
        Bytes::from_array([separator]) +
        Bytes::make(length, b'x') +
        Bytes::from_array([separator]) +
        b"tail"
      for before in [false, true] {
        assert_eq(
          reversed(data, Bytes::from_array([separator]), before, size=65536),
          reversed_byte_oracle(data, separator, before),
        )
      }
    }
  }
}

///|
async test "tac reverses newline records and preserves a trailing separator" {
  assert_eq(reversed(b"one\ntwo\nthree\n", b"\n", false), b"three\ntwo\none\n")
  assert_eq(reversed(b"one\ntwo\nthree", b"\n", false), b"threetwo\none\n")
}

///|
async test "tac supports fixed separators across backward blocks" {
  assert_eq(reversed(b"a--b--c", b"--", false), b"cb--a--")
  assert_eq(reversed(b"a--b", b"--", true), b"--ba")
  assert_eq(reversed(b"a--b--", b"--", true), b"----ba")
  assert_eq(reversed(b"ababaX", b"aba", false), b"Xababa")
  assert_eq(reversed(b"a\x00b\x00", b"\x00", false), b"b\x00a\x00")
  assert_eq(reversed(b"AaaaaabBaaaaabC", b"aaaaab", false), b"CBaaaaabAaaaaab")
  assert_eq(
    reversed(b"no separator", b"much longer separator", false),
    b"no separator",
  )
  assert_eq(reversed(b"", b"\n", false), b"")
}

///|
async test "tac regex uses bounded rightmost spans including empty matches" {
  let overlap = @bytere.compile("aba", emacs=true)
  assert_eq(reversed(b"ababaX", b"aba", false, regex=Some(overlap)), b"Xababa")
  assert_eq(reversed(b"ababaX", b"aba", true, regex=Some(overlap)), b"abaXab")
  let nullable = @bytere.compile("a*", emacs=true)
  assert_eq(reversed(b"aaBC", b"a*", false, regex=Some(nullable)), b"CBaa")
}

///|
async test "tac spools a nonseekable input and retains the complete regex span" {
  let span = FixedArray::make(65539, b'x').unsafe_reinterpret_as_bytes()
  let output = @io.MemoryReader(writer => {
    let input = @io.MemoryReader(source => {
      source.write("A<")
      source.write(span)
      source.write(">B")
    })
    defer input.close()
    reverse_spooled(
      input,
      b"<x*>",
      false,
      regex=Some(@bytere.compile("<x*>", emacs=true)),
      writer~,
    )
  })
  defer output.close()
  assert_eq(output.read_exactly(3), b"BA<")
  assert_eq(output.read_exactly(span.length()), span)
  assert_eq(output.read_all().binary(), b">")
}

///|
async test "tac byte ranges retain 64-bit sparse offsets" {
  // The current public API cannot mark a Windows file sparse; avoid requiring
  // a physical 4 GiB zero-filled allocation for this seek regression there.
  if @platform.is_windows() {
    return
  }
  let root = @fs.tmpdir(prefix="cli-tac-offset-test-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fs.open(
    root + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  let start = 4294967296L - 2L
  file.write_at(b"tail", position=start)
  let output = @io.MemoryReader(writer => {
    @tempio.copy_range(
      file,
      start,
      start + 4L,
      FixedArray::make(3, b'\x00'),
      writer,
    )
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"tail")
}

///|
async test "tac propagates output closure without retrying a buffered write" {
  let root = @fs.tmpdir(prefix="cli-tac-write-test-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fs.open(
    root + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  file.write("one\ntwo\n")
  let (reader, writer) = @io.pipe()
  reader.close()
  defer writer.close()
  let closed = try {
    reverse_file(file, b"\n", false, writer~)
    false
  } catch {
    @io.PipeClosed => true
    error => raise error
  }
  assert_true(closed)
}

///|
priv suberror TacInterruptedInput {
  TacInterruptedInput
}

///|
async test "tac emits nothing when input spooling is interrupted" {
  let interrupted = Ref(false)
  let output = @io.MemoryReader(writer => {
    let input = @io.MemoryReader(source => {
      source.write("one\ntwo\n")
      raise TacInterruptedInput
    })
    defer input.close()
    reverse_spooled(input, b"\n", false, writer~) catch {
      TacInterruptedInput => interrupted.val = true
      error => raise error
    }
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"")
  assert_true(interrupted.val)
}

///|
async test "tac verifies nominal regular extents before using backward reads" {
  let root = @fs.tmpdir(prefix="cli-tac-extent-test-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let file = @fs.open(
    root + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  assert_true(has_extent(file, 0L))
  assert_true(!has_extent(file, 4096L))
  file.write("one\ntwo\n")
  assert_true(has_extent(file, file.size()))
  assert_true(!has_extent(file, 0L))
  assert_true(!has_extent(file, 4096L))
  // The probes are positional and leave the stream at its original start.
  let output = @io.MemoryReader(writer => {
    reverse_spooled(file, b"\n", false, writer~)
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"two\none\n")
}
