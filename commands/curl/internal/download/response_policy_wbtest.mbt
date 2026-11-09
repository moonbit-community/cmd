///|
test "curl redirected stdin requires rewind only after payload was sent" {
  require_replayable_redirect(StdinBody, 0L)
  require_replayable_redirect(EmptyBody, 3L)
  require_replayable_redirect(FileBody("reopenable"), 3L)
  try require_replayable_redirect(StdinBody, 3L) catch {
    @netops.TransferError(kind~, context~, ..) => {
      assert_eq(kind, RewindFailure)
      assert_eq(context, Some(failure_context(Request)))
    }
  } noraise {
    _ => fail("a consumed redirected stdin must require rewind")
  }
}

///|
async test "final header EOF retains completed fields" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = serve_raw_response(group, "HTTP/1.1 200 OK\r\nContent-Len")
      let result = try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          DiscardOutput,
          options(),
        )
      catch {
        @netops.TransferError(kind~, context~, ..) => {
          assert_eq(kind, ReceiveFailure)
          assert_eq(context, Some(failure_context(ResponseHeaders)))
          None
        }
        error => raise error
      } noraise {
        result => Some(result.received)
      }
      assert_eq(result, Some(0L))
    })
  })
}

///|
async test "Wget  accepts only calibrated chunk EOF states" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        (body, delivered, _wget_success) in [
          ("", 0L, false),
          ("5\r\n", 0L, true),
          ("9\r\nhello", 5L, true),
          ("5\r\nhello", 5L, false),
          ("5\r\nhello\r\n", 5L, false),
          ("5\r\nhello\r\n0\r\nX-Trailer: yes\r\n", 5L, true),
        ] {
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + body,
        )
        let result = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            DiscardOutput,
            options(),
          )
        catch {
          @netops.TransferError(kind~, context~, ..) => {
            assert_eq(kind, PartialBodyFailure)
            assert_eq(
              context,
              Some(
                failure_context(
                  ResponseBody,
                  framing=Chunked,
                  received_bytes=delivered,
                ),
              ),
            )
            None
          }
          error => raise error
        } noraise {
          result => Some(result.received)
        }
        assert_eq(result, None)
      }
    })
  })
}

///|
async test "curl lazy files distinguish failed empty bodies from successful empty responses" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-curl-lazy-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for
        (name, response, success) in [
          ("failed", "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n", false),
          ("empty", "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n", true),
          ("header-eof", "HTTP/1.1 200 OK\r\nContent-Len", true),
        ] {
        let path = directory + "/" + name
        let server = serve_raw_response(group, response)
        let actual_success = try
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
            assert_eq(kind, PartialBodyFailure)
            assert_eq(
              context,
              Some(failure_context(ResponseBody, framing=FixedLength(9L))),
            )
            false
          }
          error => raise error
        } noraise {
          _ => true
        }
        assert_eq(actual_success, success)
        assert_eq(@fs.exists(path), success)
        if success {
          assert_eq(@fs.read_file(path).binary(), b"")
        }
      }
    })
  })
}
