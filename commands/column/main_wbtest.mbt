///|
async fn table(
  lines : Array[String],
  separator : String?,
  output_separator : String,
) -> String {
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=true, separator~, snapshot => {
      for line in lines {
        snapshot.append(line)
      }
      snapshot.finish()
      snapshot.render_table(writer, output_separator)
      false
    })
  })
  output.read_all().text()
}

///|
async fn columns(
  lines : Array[String],
  width : Int32,
  fill_rows : Bool,
) -> String {
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=false, separator=None, snapshot => {
      for line in lines {
        snapshot.append(line)
      }
      snapshot.finish()
      snapshot.render_grid(writer, width, fill_rows)
      false
    })
  })
  output.read_all().text()
}

///|
async test "column aligns whitespace fields" {
  assert_eq(
    table(["name age", "Ada 36", "Bob 7"], None, "  "),
    "name  age\nAda   36\nBob   7\n",
  )
}

///|
async test "column accepts an explicit delimiter and output separator" {
  assert_eq(table(["a:b", "cc:ddd"], Some(":"), " | "), "a  | b\ncc | ddd\n")
}

///|
async test "column handles empty fields, uneven rows and multiple delimiters" {
  assert_eq(
    table(["a::b,c", "xx:,d"], Some(":,"), "  "),
    "a     b  c\nxx    d  \n",
  )
  assert_eq(
    table(["a b", "c", "z d e"], None, "  "),
    "a  b  \nc     \nz  d  e\n",
  )
  assert_eq(table(["a b", "cc dd"], Some(""), "  "), "a b\ncc dd\n")
}

///|
async test "column fills columns and rows at explicit widths" {
  assert_eq(columns(["a", "b", "c", "d", "e"], 16, false), "a\td\nb\te\nc\n")
  assert_eq(columns(["a", "b", "c", "d", "e"], 16, true), "a\tb\nc\td\ne\n")
  assert_eq(columns(["one", "two"], 80, false), "one\ttwo\n")
  assert_eq(columns(["one", "two"], 0, false), "one\ntwo\n")
  assert_eq(input_line(b" \t"), None)
  assert_eq(input_line(b"hello\x00hidden"), Some("hello"))
  assert_eq(input_line(b"\xff x"), Some("\\xff x"))
}

///|
async test "column table width ignores complete color escapes only" {
  assert_eq(
    table(["a\u001b[31mb:c", "long:d"], Some(":"), "  "),
    "a\u001b[31mb    c\nlong  d\n",
  )
  assert_eq(display_width("a\u001b[31mb"), 6)
  assert_eq(display_width("a\u001b[31mb", table=true), 2)
  assert_eq(display_width("a\u001b[31b", table=true), 5)
}

///|
async test "column snapshot handles index pages and reordered grid access" {
  let _ = with_snapshot(table=false, separator=None, snapshot => {
    for i in 0..<4353 {
      snapshot.append(i.to_string())
    }
    snapshot.finish()
    for page in 0..<18 {
      let i = page * 256
      assert_eq(snapshot.line(i.to_int64()), i.to_string())
    }
    for i in [0, 255, 256, 4095, 4096, 4352, 300, 0, 4352] {
      assert_eq(snapshot.line(i.to_int64()), i.to_string())
    }
    assert_true(snapshot.index.pages.length() <= 16)
    assert_true(snapshot.data.pages.length() <= 16)
    false
  })
}

///|
async test "column wide grid retains interleaved index pages without changing bytes" {
  let record : (Int32) -> String = index => {
    let text = index.to_string()
    "0".repeat(7 - text.length()) + text
  }
  let expected = StringBuilder()
  for row in 0..<34 {
    for column in 0..<128 {
      if column > 0 {
        expected.write_char('\t')
      }
      expected.write_string(record(row + column * 34))
    }
    expected.write_char('\n')
  }
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=false, separator=None, snapshot => {
      assert_eq(snapshot.data.capacity, 16)
      assert_eq(snapshot.index.capacity, 16)
      for i in 0..<4352 {
        snapshot.append(record(i))
      }
      snapshot.finish()
      snapshot.render_grid(writer, 1024, false)
      assert_eq(snapshot.data.capacity, 128)
      assert_eq(snapshot.index.capacity, 128)
      assert_eq(snapshot.index.pages.length(), 17)
      false
    })
  })
  assert_eq(output.read_all().text(), expected.to_string())
}

///|
async test "column formats the consumed snapshot after source mutation" {
  let root = @fs.tmpdir(prefix="column-snapshot-test-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/input"
  @fs.write_file(path, "a b\nlong c\n")
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=true, separator=None, snapshot => {
      {
        let source = @fs.open(path, mode=ReadOnly)
        defer source.close()
        snapshot.consume(source)
      }
      snapshot.finish()
      @fs.write_file(path, "changed after the first pass\n")
      snapshot.render_table(writer, "  ")
      false
    })
  })
  assert_eq(output.read_all().text(), "a     b\nlong  c\n")
}

///|
async test "column consumes long byte records and preserves unterminated EOF" {
  let long = "x".repeat(70000)
  let source = @io.MemoryReader(writer => {
    writer.write(" \t\n" + long + "\n")
    writer.write(b"a\x00hidden\n\xff tail")
  })
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=false, separator=None, snapshot => {
      snapshot.consume(source)
      snapshot.finish()
      assert_eq(snapshot.records, 3L)
      snapshot.render_grid(writer, 0, false)
      false
    })
  })
  assert_eq(output.read_all().text(), long + "\na\n\\xff tail\n")
}

///|
test "column layout and disk index arithmetic cross 2 GiB and 4 GiB" {
  assert_eq(grid_shape(4294967297L, 1, 16), (8L, 2L, 2147483649L))
  assert_eq(grid_shape(1L, 2147483646, 2147483647), (2147483648L, 1L, 1L))
  let entry = Buffer()
  entry.write_int64_le(4294967297L)
  entry.write_int64_le(2147483648L)
  assert_eq(index_number(entry.contents(), 0), 4294967297L)
  assert_eq(index_number(entry.contents(), 8), 2147483648L)
}

///|
async test "column retains complete records before an input failure" {
  let source = @io.MemoryReader(writer => {
    writer.write("one\npartial")
    @async.sleep(1)
    fail("fixture input failure")
  })
  defer source.close()
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=false, separator=None, snapshot => {
      try snapshot.consume(source) catch {
        InputError(message) =>
          assert_true(message.contains("fixture input failure"))
        error => raise error
      } noraise {
        _ => fail("must preserve the input error")
      }
      assert_eq(snapshot.records, 1L)
      snapshot.finish()
      snapshot.render_grid(writer, 0, false)
      false
    })
  })
  assert_eq(output.read_all().text(), "one\n")
}

///|
priv struct PrefixWriter {
  bytes : Array[Byte]
  mut remaining : Int32
  mut calls : Int32
}

///|
impl @io.Writer for PrefixWriter with fn write_once(self, data, offset~, len~) {
  self.calls += 1
  guard self.remaining > 0 else { fail("fixture output failure") }
  let count = len.min(self.remaining)
  for i in offset..<(offset + count) {
    self.bytes.push(data[i])
  }
  self.remaining -= count
  count
}

///|
async test "column stops on a failed output and retains its written prefix" {
  let output : PrefixWriter = { bytes: [], remaining: 2, calls: 0, }
  try
    with_snapshot(table=false, separator=None, snapshot => {
      snapshot.append("one")
      snapshot.append("two")
      snapshot.finish()
      snapshot.render_grid(output, 0, false)
      false
    })
    |> ignore
  catch {
    error => assert_true(error.to_string().contains("fixture output failure"))
  } noraise {
    _ => fail("must propagate output failure")
  }
  assert_eq(Bytes::from_array(output.bytes), b"on")
  assert_eq(output.calls, 2)
}
