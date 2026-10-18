///|
async test "transfer timeouts identify stalled request headers and body phases" {
  @async.with_timeout(15000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-timeout-phases-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for phase in [Request, ResponseHeaders, ResponseBody] {
        let path = directory + "/output"
        if @fs.exists(path) {
          @fs.remove(path)
        }
        let headers_seen : Array[String] = []
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        group.add_defer(() => server.close())
        group.spawn_bg(no_wait=true, () => {
          server.run_forever((connection, _) => {
            let request = StringBuilder()
            while connection.read_until("\r\n") is Some(line) && line != "" {
              request.write_string(line + "\r\n")
            }
            headers_seen.push(request.to_string())
            if phase == ResponseBody {
              connection.write(
                "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nabc",
              )
            }
            // Keep the socket open without reading the upload or completing
            // the response. The transfer deadline must precede fixture EOF.
            @async.sleep(10000)
          })
        })
        let body = if phase == Request {
          BytesBody(Bytes::from_array(Array::make(32 * 1024 * 1024, b'x')))
        } else {
          EmptyBody
        }
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/stall",
            FileOutput(
              path~,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            transfer_options(
              body~,
              idle_timeout_ms=250,
              connect_timeout_ms=2000,
            ),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(kind, TimeoutFailure)
            guard context is Some(context) else {
              fail("missing timeout context")
            }
            assert_eq(context.phase, phase)
            if phase == ResponseBody {
              assert_eq(context.framing, Some(FixedLength(9L)))
              assert_eq(context.received_bytes, 3L)
              assert_eq(context.committed_bytes, 3L)
              assert_false(context.write_outcome_uncertain)
            } else {
              assert_eq(context.framing, None)
              assert_eq(context.received_bytes, 0L)
              assert_eq(context.committed_bytes, 0L)
            }
            true
          }
          error => raise error
        } noraise {
          _ => false
        }
        assert_true(failure)
        assert_eq(headers_seen.length(), 1)
        if phase == ResponseBody {
          assert_eq(@fs.read_file(path).binary(), b"abc")
        } else {
          assert_false(@fs.exists(path))
        }
      }
    })
  })
}
