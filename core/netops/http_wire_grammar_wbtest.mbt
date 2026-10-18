///|
async test "wire chunk extensions preserve BWS quoted values and reject malformed syntax" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        (extension, valid) in [
          (" ;x=y", true),
          ("; x = \"quoted\\\"\\\\\" ; flag ; final = token \t", true),
          (";=bad", false),
          (";x=\"unterminated", false),
          (";x=", false),
          (";x=\"closed\"bad", false),
        ] {
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5" +
          extension +
          "\r\nhello\r\n0\r\n\r\n",
        )
        let received = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            DiscardOutput,
            transfer_options(),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(kind, ReceiveFailure)
            assert_eq(
              context,
              Some(failure_context(ResponseBody, framing=Chunked)),
            )
            None
          }
          error => raise error
        } noraise {
          result => Some(result.received)
        }
        assert_eq(received, if valid { Some(5L) } else { None })
      }
    })
  })
}

///|
async test "wire headers reject raw control bytes before trimming HTTP whitespace" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for (value, valid) in [(" \t3\t ", true), (" 3\r", false), ("\r3", false)] {
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nContent-Length:" + value + "\r\n\r\nabc",
        )
        let received = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            DiscardOutput,
            transfer_options(),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(kind, ReceiveFailure)
            assert_eq(context, Some(failure_context(ResponseHeaders)))
            None
          }
          error => raise error
        } noraise {
          result => Some(result.received)
        }
        assert_eq(received, if valid { Some(3L) } else { None })
      }
    })
  })
}

///|
async test "wire Set-Cookie trailers fail after retaining the delivered payload" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nSet-Cookie: late=1\r\n\r\n",
      )
      try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          DiscardOutput,
          transfer_options(),
        )
      catch {
        TransferError(kind~, context~, ..) => {
          assert_eq(kind, ReceiveFailure)
          assert_eq(
            context,
            Some(
              failure_context(ResponseBody, framing=Chunked, received_bytes=5L),
            ),
          )
        }
        error => raise error
      } noraise {
        _ => fail("Set-Cookie trailers must fail")
      }
    })
  })
}
