///|
async test "transfer sink scope closes real files on cancellation and repeated close is safe" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-sink-cancel-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for profile in [StrictProfile, CurlProfile] {
        let path = directory + "/body"
        let response : @http.Response = {
          code: 200,
          reason: "OK",
          headers: {},
          cookies: [],
        }
        let sink = TransferSink::new(
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition=false,
            remove_on_error=false,
          ),
          response,
          profile,
        )
        let ready = Ref(false)
        let changed = @cond_var.Cond()
        let task = group.spawn(() => {
          @async.handle_cancellation(() => {
            sink.with_scope(() => {
              sink.start(None, 0L)
              sink.write(b"hello")
              ready.val = true
              changed.signal()
              @async.sleep(10000)
            })
          })
        })
        while !ready.val {
          changed.wait()
        }
        guard sink.sink is Some(FileSink(_, file, _)) else {
          fail("the cancellation fixture must own an opened file")
        }
        let open_descriptor = file.fd()
        task.cancel()
        assert_true(task.wait() is None)
        let closed_descriptor = file.fd()
        assert_true(closed_descriptor != open_descriptor)
        assert_eq(sink.path(), Some(path))
        // Observe the closed alias without submitting I/O on it: the Wasm
        // host rejects a closed-handle job before a MoonBit error can be caught.
        let other_path = directory + "/other"
        let other = @fs.create(other_path)
        defer other.close()
        sink.close()
        assert_true(file.fd() == closed_descriptor)
        other.write(b"still open")
        assert_eq(@fs.read_file(other_path).binary(), b"still open")
      }
    })
  })
}
