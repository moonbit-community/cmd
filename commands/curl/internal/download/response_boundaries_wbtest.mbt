///|
async test "resumed chunked and close delimited bodies must satisfy their Content-Range span" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-range-span-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for chunked in [true, false] {
        for complete in [true, false] {
          @fs.write_file(path, "abc")
          let payload = if complete { "def" } else { "de" }
          let body = if chunked {
            "\{payload.length()}\r\n" + payload + "\r\n0\r\n\r\n"
          } else {
            payload
          }
          let wire = "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 3-5/6\r\n" +
            (if chunked {
              "Transfer-Encoding: chunked\r\n"
            } else {
              "Connection: close\r\n"
            }) +
            "\r\n" +
            body
          let server = serve_raw_response(group, wire)
          let failure = try
            transfer(
              "http://127.0.0.1:\{server.addr.port()}/",
              FileOutput(
                path~,
                mode=Append,
                content_disposition=false,
                remove_on_error=false,
              ),
              options(resume_from=3L),
            )
          catch {
            @netops.TransferError(kind~, context~, ..) => {
              assert_eq(
                context,
                Some(
                  failure_context(
                    ResponseBody,
                    framing=if chunked { Chunked } else { CloseDelimited },
                    received_bytes=2L,
                    committed_bytes=2L,
                  ),
                ),
              )
              Some(kind)
            }
            error => raise error
          } noraise {
            result => {
              assert_eq(result.received, 3L)
              None
            }
          }
          assert_eq(
            failure,
            if complete {
              None
            } else {
              Some(@netops.PartialBodyFailure)
            },
          )
          assert_eq(@fs.read_file(path).text(), "abc" + payload)
        }
      }
    })
  })
}

///|
async test "response body EOF has a distinct failure and retains the delivered prefix" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-body-eof-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for
        (response, kind, expected) in [
          (
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n9\r\nabc",
            @netops.PartialBodyFailure,
            "abc",
          ),
        ] {
        let server = serve_raw_response(group, response)
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            options(),
          )
        catch {
          @netops.TransferError(kind~, context~, ..) => {
            guard context is Some(context) else {
              fail("missing body failure context")
            }
            assert_eq(context.phase, ResponseBody)
            assert_eq(
              context.received_bytes,
              @utf8.encode(expected).length().to_int64(),
            )
            assert_eq(
              context.committed_bytes,
              @utf8.encode(expected).length().to_int64(),
            )
            assert_false(context.write_outcome_uncertain)
            assert_eq(
              context.framing,
              Some(
                if response.contains("Content-Length") {
                  FixedLength(9L)
                } else {
                  Chunked
                },
              ),
            )
            Some(kind)
          }
          error => raise error
        } noraise {
          _ => None
        }
        assert_eq(failure, Some(kind))
        assert_eq(@fs.read_file(path).text(), expected)
      }
    })
  })
}

///|
async test "failed file sink writes remain output failures and preserve the file" {
  let directory = @fs.tmpdir(prefix="netops-output-error-")
  defer @async.protect_from_cancel(() => @fs.rmdir(directory, recursive=true))
  let path = directory + "/body"
  @fs.write_file(path, "preserve")
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let failure = try
    OutputSink::FileSink(path, file, false).write(b"replacement")
  catch {
    @netops.TransferError(..) as error =>
      Some(
        response_body_failure(
          error,
          FixedLength(11L),
          received_bytes=11L,
          committed_bytes=0L,
        ),
      )
    error => raise error
  } noraise {
    _ => None
  }
  guard failure is Some(@netops.TransferError(kind~, context~, ..)) else {
    fail("expected a file write failure")
  }
  assert_eq(kind, OutputFailure)
  assert_eq(
    context,
    Some(
      failure_context(
        ResponseBody,
        framing=FixedLength(11L),
        received_bytes=11L,
        committed_bytes=0L,
        write_outcome_uncertain=true,
      ),
    ),
  )
  assert_eq(@fs.read_file(path).text(), "preserve")
}

///|
test "body failure context preserves completed write lower bounds and error kinds" {
  let failed = response_body_failure(
    transfer_error(OutputFailure, "failed after a completed prefix", status=200),
    Chunked,
    received_bytes=9L,
    committed_bytes=3L,
  )
  let @netops.TransferError(kind~, status~, context~, ..) = failed
  assert_eq(kind, OutputFailure)
  assert_eq(status, Some(200))
  assert_eq(
    context,
    Some(
      failure_context(
        ResponseBody,
        framing=Chunked,
        received_bytes=9L,
        committed_bytes=3L,
        write_outcome_uncertain=true,
      ),
    ),
  )
  let read_failure = response_body_failure(
    transfer_error(@netops.PartialBodyFailure, "body ended"),
    FixedLength(12L),
    received_bytes=9L,
    committed_bytes=6L,
  )
  let @netops.TransferError(kind~, context~, ..) = read_failure
  assert_eq(kind, @netops.PartialBodyFailure)
  assert_eq(
    context,
    Some(
      failure_context(
        ResponseBody,
        framing=FixedLength(12L),
        received_bytes=9L,
        committed_bytes=6L,
      ),
    ),
  )
}
