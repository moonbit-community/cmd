///|
priv struct PasteOutput {
  bytes : Array[Byte]
}

///|
priv struct StalledPasteOutput {
  ready : @async.Queue[Unit]
  release : @async.Queue[Unit]
}

///|
impl @io.Writer for StalledPasteOutput with fn write_once(
  self,
  _,
  offset~,
  len~,
) {
  ignore(offset)
  self.ready.put(())
  ignore(self.release.get())
  len
}

///|
async test "paste deferred output remains cancellable under backpressure" {
  @async.with_timeout(5000, () => {
    for serial in [true, false] {
      let reader = @io.MemoryReader(writer => writer.write(b"one\n"))
      defer reader.close()
      let scanner = @stream.LineScanner::new(reader)
      @async.with_task_group(group => {
        let ready : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
        let release : @async.Queue[Unit] = @async.Queue(kind=Unbounded)
        defer ignore(release.try_put(()))
        let output : StalledPasteOutput = { ready, release, }
        let task = group.spawn(() => {
          if serial {
            paste_serial(scanner, [b","], b'\n', writer=output)
          } else {
            paste_parallel([scanner], [b","], b'\n', writer=output)
          }
        })
        ignore(ready.get())
        task.cancel()
        let cancelled = try {
          task.wait()
          false
        } catch {
          @async.WaitedTaskAlreadyCancelled => true
          error => raise error
        }
        assert_true(cancelled)
      })
    }
  })
}

///|
impl @io.Writer for PasteOutput with fn write_once(self, bytes, offset~, len~) {
  for i in offset..<(offset + len) {
    self.bytes.push(bytes[i])
  }
  len
}

///|
async test "paste serial delimiters and repeated input ownership preserve bytes" {
  for serial in [true, false] {
    let reader = @io.MemoryReader(writer => writer.write(b"a\x00b\x00\xfftail"))
    defer reader.close()
    let scanner = @stream.LineScanner::new(reader, delimiter=b'\x00')
    let output : PasteOutput = { bytes: [], }
    if serial {
      paste_serial(scanner, [b",", b""], b'\x00', writer=output)
    } else {
      paste_parallel([scanner, scanner], [b","], b'\x00', writer=output)
    }
    assert_eq(
      Bytes::from_array(output.bytes),
      if serial {
        b"a,b\xfftail\x00"
      } else {
        b"a,b\x00\xfftail,\x00"
      },
    )
  }
}

///|
async test "paste preserves the emitted prefix on input failure" {
  for serial in [true, false] {
    let reader = @io.MemoryReader(writer => {
      writer.write(b"one\nfragment")
      fail("injected read failure")
    })
    defer reader.close()
    let scanner = @stream.LineScanner::new(reader)
    let output : PasteOutput = { bytes: [], }
    let failed = try {
      if serial {
        paste_serial(scanner, [b","], b'\n', writer=output)
      } else {
        paste_parallel([scanner], [b","], b'\n', writer=output)
      }
      false
    } catch {
      _ => true
    }
    assert_true(failed)
    assert_eq(
      Bytes::from_array(output.bytes),
      if serial {
        b"one"
      } else {
        b"one\n"
      },
    )
  }
}
