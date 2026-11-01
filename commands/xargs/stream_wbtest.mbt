///|
fn test_batches(
  reader : &@io.Reader,
  mode~ : InputMode = Words,
  max_args~ : Int32 = 1,
  max_lines~ : Int32 = 0,
  max_bytes~ : Int64 = 64L,
) -> BatchReader {
  {
    input: ItemReader::new(reader, mode, max_bytes.to_int()),
    program: "cmd",
    prefix: [],
    prefix_bytes: 4L,
    max_args,
    max_lines,
    max_bytes,
    replace: None,
    eof: None,
    no_empty: true,
    pending: None,
    emitted: false,
  }
}

///|
async test "xargs dispatches complete batches while the producer keeps input open" {
  @async.with_timeout(5000, () => {
    let acknowledged : @async.Queue[String] = @async.Queue(kind=Blocking(1))
    let input = @io.MemoryReader(writer => {
      writer.write("first\n")
      assert_eq(acknowledged.get(), "first")
      writer.write("second\n")
      assert_eq(acknowledged.get(), "second")
    })
    defer input.close()
    let seen : Array[String] = []
    assert_eq(
      run_xargs_stream(test_batches(input), 1, args => {
        seen.push(args[0])
        acknowledged.put(args[0])
        0
      }),
      0,
    )
    assert_eq(seen, ["first", "second"])
  })
}

///|
async test "xargs refills free slots without waiting for a slow earlier child" {
  @async.with_timeout(5000, () => {
    let release : @async.Queue[Unit] = @async.Queue(kind=Blocking(1))
    let input = @io.MemoryReader(writer => writer.write("slow fast third\n"))
    defer input.close()
    let mut active = 0
    let mut maximum = 0
    assert_eq(
      run_xargs_stream(test_batches(input), 2, args => {
        active += 1
        maximum = maximum.max(active)
        defer {
          active -= 1
        }
        match args[0] {
          "slow" => {
            release.get()
            1
          }
          "third" => {
            release.put(())
            0
          }
          _ => 0
        }
      }),
      123,
    )
    assert_eq(maximum, 2)
    assert_eq(active, 0)
  })
}

///|
async test "xargs fatal child status interrupts an open producer and preserves launch failures" {
  for status in [255, 126, 127] {
    @async.with_timeout(5000, () => {
      let input = @io.MemoryReader(writer => {
        writer.write("one\n")
        @async.sleep(60000)
      })
      defer input.close()
      assert_eq(
        run_xargs_stream(test_batches(input), 2, _ => status),
        if status == 255 {
          124
        } else {
          status
        },
      )
    })
  }
}

///|
async test "xargs fragmented tokens preserve UTF-8 quotes escapes and delimiter empties" {
  for
    (data, mode, expected) in [
      (
        b"one 'two three' four\\ five \xc3\xa9 \"\"",
        Words,
        ["one", "two three", "four five", "\u00e9", ""],
      ),
      (b"a,,b,", Delimited(44), ["a", "", "b"]),
    ] {
    let input = @io.MemoryReader(writer => {
      for byte in data {
        writer.write(Bytes::from_array([byte]))
        @async.sleep(1)
      }
    })
    defer input.close()
    let batches = test_batches(input, mode~)
    let actual : Array[String] = []
    while batches.next() is Some(args) {
      actual.append(args)
    }
    assert_eq(actual, expected)
  }
}

///|
async test "xargs batches count multibyte arguments once and preserve line groups" {
  let input = @io.MemoryReader(writer => writer.write("\u00e9 \u00e9 x\n"))
  defer input.close()
  let batches = test_batches(input, max_args=0, max_bytes=10L)
  assert_eq(batches.next(), Some(["\u00e9", "\u00e9"]))
  assert_eq(batches.next(), Some(["x"]))
  assert_eq(batches.next(), None)
  let lines = @io.MemoryReader(writer => {
    writer.write("one two\n\nthree\nfour five\n")
  })
  defer lines.close()
  let grouped = test_batches(lines, mode=Lines, max_args=0, max_lines=2)
  assert_eq(grouped.next(), Some(["one", "two", "three"]))
  assert_eq(grouped.next(), Some(["four", "five"]))
  assert_eq(grouped.next(), None)
}
