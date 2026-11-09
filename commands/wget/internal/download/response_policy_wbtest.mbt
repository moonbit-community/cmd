///|
async test "Wget HEAD partial responses require an actual Range request" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for explicit_range in [false, true] {
        let server = serve_raw_response(
          group, "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 3-5/6\r\nContent-Length: 3\r\n\r\n",
        )
        let success = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            DiscardOutput,
            options(
              request_method=Head,
              headers=if explicit_range {
                [@netops.http_header("Range", "bytes=3-")]
              } else {
                []
              },
            ),
          )
        catch {
          @netops.TransferError(kind~, ..) => {
            assert_eq(kind, ReceiveFailure)
            false
          }
          error => raise error
        } noraise {
          result => {
            assert_eq(result.received, 0L)
            true
          }
        }
        assert_eq(success, explicit_range)
      }
    })
  })
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
        (body, delivered, wget_success) in [
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
        assert_eq(result, if wget_success { Some(delivered) } else { None })
      }
    })
  })
}

///|
async test "Wget 416  preserves outputs independently of range metadata or resume state" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wget-416-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for range in ["bytes */6", "bytes */bad", "missing"] {
        for prefix in [Some("abc"), Some("abcdef"), Some("abcdefg"), None] {
          if @fs.exists(path) {
            @fs.remove(path)
          }
          if prefix is Some(prefix) {
            @fs.write_file(path, prefix)
          }
          let server = serve_raw_response(
            group,
            "HTTP/1.1 416 Range Not Satisfiable\r\n" +
            (if range == "missing" {
              ""
            } else {
              "Content-Range: " + range + "\r\n"
            }) +
            "Content-Length: 0\r\n\r\n",
          )
          let result = transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Append,
              content_disposition=false,
              remove_on_error=false,
            ),
            options(
              fail_on_http_error=true,
              resume_from?=prefix.map(value => value.length().to_int64()),
            ),
          )
          assert_eq(result.status, 416)
          assert_eq(result.received, 0L)
          assert_eq(@fs.exists(path), prefix is Some(_))
          if prefix is Some(prefix) {
            assert_eq(@fs.read_file(path).text(), prefix)
          }
        }
      }
    })
  })
}

///|
async test "Wget range mismatch is a receive failure and a complete shorter response preserves its prefix" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wget-range--")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      @fs.write_file(path, "preserve")
      for
        (response, success) in [
          (
            "HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 9-10/11\r\nContent-Length: 2\r\n\r\nxy",
            false,
          ),
          ("HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nabcdef", true),
        ] {
        let server = serve_raw_response(group, response)
        let actual_success = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Append,
              content_disposition=false,
              remove_on_error=false,
            ),
            options(resume_from=8L),
          )
        catch {
          @netops.TransferError(kind~, ..) => {
            assert_eq(kind, ReceiveFailure)
            false
          }
          error => raise error
        } noraise {
          _ => true
        }
        assert_eq(actual_success, success)
        assert_eq(@fs.read_file(path).text(), "preserve")
      }
    })
  })
}
