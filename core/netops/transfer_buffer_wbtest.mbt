///|
async test "curl lazy open failures do not report an attempted sink write" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-curl-open-failure-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello",
      )
      try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          FileOutput(
            path=directory,
            mode=Truncate,
            content_disposition=false,
            remove_on_error=false,
          ),
          transfer_options(profile=CurlProfile),
        )
      catch {
        TransferError(kind~, context~, ..) => {
          assert_eq(kind, OutputFailure)
          assert_eq(
            context,
            Some(
              failure_context(
                ResponseBody,
                framing=FixedLength(5L),
                received_bytes=5L,
              ),
            ),
          )
        }
        error => raise error
      } noraise {
        _ => fail("a directory cannot be opened as the output file")
      }
    })
  })
}

///|
async test "curl buffered file tails are retained after a network failure" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-curl-buffer-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nhello",
      )
      try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition=false,
            remove_on_error=false,
          ),
          transfer_options(profile=CurlProfile),
        )
      catch {
        TransferError(kind~, context~, ..) => {
          assert_eq(kind, PartialBodyFailure)
          assert_eq(
            context,
            Some(
              failure_context(
                ResponseBody,
                framing=FixedLength(9L),
                received_bytes=5L,
                committed_bytes=5L,
              ),
            ),
          )
        }
        error => raise error
      } noraise {
        _ => fail("the incomplete body must fail")
      }
      assert_eq(@fs.read_file(path).binary(), b"hello")
    })
  })
}

///|
async test "curl file buffering distinguishes the flush threshold and preserves primary failures" {
  let directory = @fs.tmpdir(prefix="netops-curl-flush-failure-")
  defer @async.protect_from_cancel(() => @fs.rmdir(directory, recursive=true))
  let path = directory + "/readonly"
  @fs.write_file(path, "preserve")
  let response : @http.Response = {
    code: 200,
    reason: "OK",
    headers: {},
    cookies: [],
  }
  for length in [4095, 4096] {
    let file = @fs.open(path, mode=ReadOnly)
    let sink = TransferSink::new(
      FileOutput(
        path~,
        mode=Truncate,
        content_disposition=false,
        remove_on_error=false,
      ),
      response,
      CurlProfile,
    )
    // A real read-only descriptor makes writes fail without a platform-specific
    // device; command scenarios separately compare /dev/full with the oracle.
    sink.sink = Some(FileSink(path, file, false))
    sink.started = true
    defer sink.close()
    let failure = try
      sink.write(Bytes::from_array(Array::make(length, b'x')))
    catch {
      TransferError(..) as error => error
      error => raise error
    } noraise {
      _ =>
        transfer_error(
          PartialBodyFailure,
          "response ended before its declared length",
        )
    }
    sink.flush_after_failure()
    let failure = response_body_failure(
      failure,
      FixedLength(length.to_int64() + 1L),
      received_bytes=length.to_int64(),
      committed_bytes=sink.committed,
      write_outcome_uncertain=sink.write_uncertain,
    )
    let TransferError(kind~, context~, ..) = failure
    assert_eq(
      kind,
      if length == 4095 {
        PartialBodyFailure
      } else {
        OutputFailure
      },
    )
    assert_eq(
      context,
      Some(
        failure_context(
          ResponseBody,
          framing=FixedLength(length.to_int64() + 1L),
          received_bytes=length.to_int64(),
          write_outcome_uncertain=true,
        ),
      ),
    )
    assert_eq(@fs.read_file(path).binary(), b"preserve")
  }
}

///|
async test "curl lazy cleanup leaves unopened destinations untouched after an empty failure" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-curl-lazy-cleanup-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for existing in [false, true] {
        for remove_on_error in [false, true] {
          let path = directory + "/\{existing}-\{remove_on_error}"
          if existing {
            @fs.write_file(path, "preserve")
          }
          let server = serve_raw_response(
            group, "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n",
          )
          try
            transfer(
              "http://127.0.0.1:\{server.addr.port()}/",
              FileOutput(
                path~,
                mode=Truncate,
                content_disposition=false,
                remove_on_error~,
              ),
              transfer_options(profile=CurlProfile),
            )
          catch {
            TransferError(kind~, ..) => assert_eq(kind, PartialBodyFailure)
            error => raise error
          } noraise {
            _ => fail("an incomplete body must fail")
          }
          assert_eq(@fs.exists(path), existing)
          if existing {
            assert_eq(@fs.read_file(path).binary(), b"preserve")
          }
        }
      }
    })
  })
}
