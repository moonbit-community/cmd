///|
// Keep the original single-record writer as an independent fixture path.
async fn Snapshot::append(self : Snapshot, line : String) -> Unit {
  let bytes = @utf8.encode(line)
  let entry = Buffer(size_hint=16)
  entry.write_int64_le(self.size)
  entry.write_int64_le(bytes.length().to_int64())
  self.data_writer.write(bytes)
  self.index_writer.write(entry.contents())
  self.records += 1
  self.size += bytes.length().to_int64()
  if self.table {
    for i, field in self.separator.split(line) {
      while self.widths.length() <= i {
        self.widths.push(0)
      }
      self.widths[i] = self.widths[i].max(display_width(field, table=true))
    }
  } else {
    self.longest = self.longest.max(display_width(line))
  }
}

///|
async test "column ingest bounds independent data and index batches and defers oversized rows" {
  let _ = with_snapshot(table=true, separator=Some(":"), snapshot => {
    let pending = SpoolBatch::new()
    let lines = Array::makei(8201, i => {
      if i == 4100 {
        "x".repeat(70001) + ":tail"
      } else {
        i.to_string() + ":y"
      }
    })
    for line in lines {
      let room = snapshot.stage_record(pending, line)
      assert_true(pending.data.length() <= 65536)
      assert_true(pending.index.length() <= 65536)
      if !room {
        pending.flush(snapshot.data_writer, snapshot.index_writer)
      }
    }
    pending.flush(snapshot.data_writer, snapshot.index_writer)
    snapshot.finish()
    assert_eq(snapshot.records, lines.length().to_int64())
    for i in [0, 255, 256, 4095, 4100, 4101, 8192, 8200] {
      assert_eq(snapshot.line(i.to_int64()), lines[i])
    }
    assert_eq(snapshot.widths, [70001, 4])
    false
  })
}

///|
async test "column ingest retains complete batches before an input failure" {
  let source = @io.MemoryReader(writer => {
    writer.write("a:b\n".repeat(5000) + " \t\nlast\u0000hidden\npartial")
    @async.sleep(1)
    fail("fixture batched input failure")
  })
  defer source.close()
  let _ = with_snapshot(table=true, separator=Some(":"), snapshot => {
    try snapshot.consume(source) catch {
      InputError(message) =>
        assert_true(message.contains("fixture batched input failure"))
      error => raise error
    } noraise {
      _ => fail("expected input error")
    }
    snapshot.finish()
    assert_eq(snapshot.records, 5001L)
    assert_eq(snapshot.line(4999L), "a:b")
    assert_eq(snapshot.line(5000L), "last")
    false
  })
}

///|
async test "column ingest rejects offset overflow before modifying pending bytes" {
  let _ = with_snapshot(table=false, separator=None, snapshot => {
    let pending = SpoolBatch::new()
    snapshot.size = 9223372036854775806L
    try snapshot.stage_record(pending, "ab") |> ignore catch {
      LayoutError(_) => ()
      error => raise error
    } noraise {
      _ => fail("expected overflow")
    }
    assert_eq(pending.data.length(), 0)
    assert_eq(pending.index.length(), 0)
    assert_eq(snapshot.records, 0L)
    false
  })
}
