///|
fn FieldSeparator::split(self : FieldSeparator, line : String) -> Array[String] {
  let fields : Array[String] = []
  let mut start = 0
  for index, char in line {
    if char.to_int() < 128 && self.members[char.to_int()] {
      if self.preserve_empty || index > start {
        fields.push(line[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if self.preserve_empty || start < line.length() {
    fields.push(line[start:].to_owned())
  }
  fields
}

///|
fn TableRow::new(
  snapshot : Snapshot,
  line : String,
  separator : Bytes,
) -> TableRow {
  TableRow::from_bytes(snapshot, @utf8.encode(line)[:], separator, None)
}

///|
fn table_reference(
  lines : Array[String],
  separator : String?,
  output_separator : String,
) -> String {
  let widths : Array[Int32] = []
  let rows = lines.map(line => split_fields_reference(line, separator))
  for row in rows {
    for index, field in row {
      while widths.length() <= index {
        widths.push(0)
      }
      widths[index] = widths[index].max(display_width(field, table=true))
    }
  }
  let result = StringBuilder()
  for row in rows {
    for index in 0..<widths.length() {
      let field = row.get(index).unwrap_or("")
      result.write_string(field)
      if index + 1 < widths.length() {
        result.write_string(
          " ".repeat(widths[index] - display_width(field, table=true)),
        )
        result.write_string(output_separator)
      }
    }
    result.write_char('\n')
  }
  result.to_string()
}

///|
fn split_fields_reference(line : String, separator : String?) -> Array[String] {
  let fields : Array[String] = []
  let delimiters = separator.unwrap_or(" \t")
  let mut start = 0
  for index, char in line {
    if delimiters.contains(char.to_string()) {
      if separator is Some(_) || index > start {
        fields.push(line[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if separator is Some(_) || start < line.length() {
    fields.push(line[start:].to_owned())
  }
  fields
}

///|
test "column compiles ASCII separator membership without changing empty fields" {
  for
    separator in [
      None,
      Some(""),
      Some(":"),
      Some("a\tb"),
      Some("::,"),
      Some("\u0000"),
    ] {
    let plan = FieldSeparator::new(separator)
    for length in [0, 1, 7, 128, 257] {
      let line = @utf8.decode(
        Bytes::makei(length, index => (index % 128).to_byte()),
      )
      assert_eq(plan.split(line), split_fields_reference(line, separator))
    }
  }
}

///|
async test "column table cursors bound expanded rows and resume inside UTF-8 output separators" {
  let lines = ["short:a", "x".repeat(70001) + ":\u001b[31mb\u001b[0m", ":", ""]
  let separator = "⇥ | "
  let expected = @utf8.encode(table_reference(lines, Some(":"), separator))
  let _ = with_snapshot(table=true, separator=Some(":"), snapshot => {
    for line in lines {
      snapshot.append(line)
    }
    snapshot.finish()
    for limit in [1, 7, 65536] {
      let actual = @buffer.Buffer()
      let chunk = @buffer.Buffer(size_hint=limit)
      for line in lines {
        let row = TableRow::new(snapshot, line, @utf8.encode(separator))
        for ;; {
          let complete = row.fill(chunk, limit~)
          assert_true(chunk.length() <= limit)
          actual.write_bytes(chunk.to_bytes())
          chunk.reset()
          if complete {
            break
          }
        }
      }
      assert_eq(actual.to_bytes(), expected)
    }
    false
  })
  assert_eq(table(lines, Some(":"), separator), @utf8.decode(expected))
}

///|
async test "column table batches cross cached data pages and index eviction" {
  let lines = Array::makei(5001, index => {
    index.to_string() + ":" + "x".repeat(211)
  })
  assert_eq(table(lines, Some(":"), ""), table_reference(lines, Some(":"), ""))
  assert_eq(table([], None, "  "), "")
  assert_eq(table(["", ""], None, "  "), "\n\n")
}

///|
async test "column table batching propagates partial output failure without replay" {
  let line = "x".repeat(70000) + ":tail"
  let expected = @utf8.encode(table_reference([line], Some(":"), "  "))
  let output : PrefixWriter = { bytes: [], remaining: 65537, calls: 0, }
  try
    with_snapshot(table=true, separator=Some(":"), snapshot => {
      snapshot.append(line)
      snapshot.finish()
      snapshot.render_table(output, "  ")
      false
    })
    |> ignore
  catch {
    error => assert_true(error.to_string().contains("fixture output failure"))
  } noraise {
    _ => fail("must propagate output failure")
  }
  assert_eq(Bytes::from_array(output.bytes), expected[:65537].to_owned())
  assert_eq(output.calls, 3)
}

///|
async test "column table renders completed records after input failure" {
  let source = @io.MemoryReader(writer => {
    writer.write("one x\npartial")
    @async.sleep(1)
    fail("fixture input failure")
  })
  defer source.close()
  let output = @io.MemoryReader(writer => {
    let _ = with_snapshot(table=true, separator=None, snapshot => {
      try snapshot.consume(source) catch {
        InputError(message) =>
          assert_true(message.contains("fixture input failure"))
        error => raise error
      } noraise {
        _ => fail("must preserve input failure")
      }
      snapshot.finish()
      snapshot.render_table(writer, "  ")
      false
    })
  })
  defer output.close()
  assert_eq(output.read_all().text(), "one  x\n")
}

///|
fn input_line_scalar(data : Bytes) -> String? {
  let line = StringBuilder()
  for byte in data {
    if byte == 0 {
      break
    }
    if byte >= 128 {
      let hex = "0123456789abcdef"
      line.write_string("\\x")
      line.write_char(hex[byte.to_int() / 16].to_char().unwrap())
      line.write_char(hex[byte.to_int() % 16].to_char().unwrap())
    } else {
      line.write_char(byte.to_int().to_char().unwrap())
    }
  }
  let value = line.to_string()
  if value
    .iter()
    .all(c => c is (' ' | '\t' | '\r' | '\n' | '\u000b' | '\u000c')) {
    None
  } else {
    Some(value)
  }
}

///|
test "column ASCII conversion preserves C-byte escapes NUL truncation and whitespace" {
  for code in 0..<256 {
    let byte = Bytes::from_array([code.to_byte()])
    for
      data in [
        byte,
        b" \t" + byte + b"\r\n",
        b"before\x00" + byte,
        byte + b"\x00after",
      ] {
      assert_eq(input_line(data[:]), input_line_scalar(data))
    }
  }
  for length in [0, 1, 7, 8, 9, 63, 64, 65, 65535, 65536, 65537] {
    let ascii = Bytes::make(length, b'x')
    for
      data in [
        ascii,
        ascii + b"\xff",
        ascii + b"\x00\xff",
        b"\t\r\n" + Bytes::make(length, b' '),
      ] {
      assert_eq(input_line(data[:]), input_line_scalar(data))
    }
  }
}
