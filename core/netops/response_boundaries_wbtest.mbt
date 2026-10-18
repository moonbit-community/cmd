///|
async fn serve_raw_response(
  group : @async.TaskGroup[Unit],
  response : String,
) -> @socket.TcpServer {
  serve_raw_bytes_response(group, @utf8.encode(response))
}

///|
async fn serve_raw_bytes_response(
  group : @async.TaskGroup[Unit],
  response : Bytes,
  requests? : Array[String],
) -> @socket.TcpServer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  group.add_defer(() => server.close())
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((connection, _) => {
      let request = StringBuilder()
      while connection.read_until("\r\n") is Some(line) && line != "" {
        request.write_string(line + "\r\n")
      }
      if requests is Some(requests) {
        requests.push(request.to_string())
      }
      if !response.is_empty() {
        connection.write(response)
      }
    })
  })
  server
}

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
              transfer_options(resume_from=3L, resume_skip_existing=true),
            )
          catch {
            TransferError(kind~, context~, ..) => {
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
              Some(PartialBodyFailure)
            },
          )
          assert_eq(@fs.read_file(path).text(), "abc" + payload)
        }
      }
    })
  })
}

///|
async test "content coded bodies preserve wire bytes and fixed length failure counts" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-encoded-wire-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      // A fixed gzip member containing "hello": 25 encoded bytes, five decoded.
      let gzip : Bytes = [
        0x1f, 0x8b, 0x08, 0, 0, 0, 0, 0, 0, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07,
        0, 0x86, 0xa6, 0x10, 0x36, 0x05, 0, 0, 0,
      ]
      for explicit in [false, true] {
        for complete in [true, false] {
          let payload = if complete { gzip } else { gzip[:20].to_owned() }
          let wire = @utf8.encode(
            "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nContent-Length: 25\r\n\r\n",
          ).to_array()
          wire.append(payload.to_array())
          let requests : Array[String] = []
          let server = serve_raw_bytes_response(
            group,
            Bytes::from_array(wire),
            requests~,
          )
          let failure = try
            transfer(
              "http://127.0.0.1:\{server.addr.port()}/",
              FileOutput(
                path~,
                mode=Truncate,
                content_disposition=false,
                remove_on_error=false,
              ),
              transfer_options(
                headers=if explicit {
                  [http_header("Accept-Encoding", "gzip")]
                } else {
                  []
                },
              ),
            )
          catch {
            TransferError(kind~, context~, ..) => {
              assert_eq(
                context,
                Some(
                  failure_context(
                    ResponseBody,
                    framing=FixedLength(25L),
                    received_bytes=20L,
                    committed_bytes=20L,
                  ),
                ),
              )
              Some(kind)
            }
            error => raise error
          } noraise {
            result => {
              assert_eq(result.received, 25L)
              None
            }
          }
          assert_eq(
            failure,
            if complete {
              None
            } else {
              Some(PartialBodyFailure)
            },
          )
          assert_eq(@fs.read_file(path).binary(), payload)
          assert_eq(requests.length(), 1)
          assert_true(
            requests[0].contains(
              "Accept-Encoding: " +
              (if explicit { "gzip" } else { "identity" }) +
              "\r\n",
            ),
          )
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
            "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n",
            PartialBodyFailure,
            "",
          ),
          (
            "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nabc",
            PartialBodyFailure,
            "abc",
          ),
          (
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n9\r\nabc",
            PartialBodyFailure,
            "abc",
          ),
          (
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n",
            PartialBodyFailure,
            "abc",
          ),
          (
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\nq\r\n",
            ReceiveFailure,
            "",
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
            transfer_options(),
          )
        catch {
          TransferError(kind~, context~, ..) => {
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
async test "normal close delimited and bodyless responses do not become partial failures" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        (response, request_method, expected) in [
          ("HTTP/1.1 200 OK\r\n\r\nabc", Get, 3L),
          ("HTTP/1.1 200 OK\r\n\r\n", Get, 0L),
          ("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n", Get, 0L),
          ("HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n", Head, 0L),
          ("HTTP/1.1 204 No Content\r\n\r\n", Get, 0L),
          ("HTTP/1.1 304 Not Modified\r\n\r\n", Get, 0L),
          (
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n0\r\n\r\n",
            Get,
            3L,
          ),
        ] {
        let server = serve_raw_response(group, response)
        let result = transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          DiscardOutput,
          transfer_options(request_method~),
        )
        assert_eq(result.received, expected)
      }
    })
  })
}

///|
async test "bodyless resumed responses never require replayed prefix bytes" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-bodyless-resume-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for
        (response, request_method, prefix) in [
          ("HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n", Head, "abc"),
          ("HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n", Head, "abcdefghijkl"),
          ("HTTP/1.1 204 No Content\r\n\r\n", Get, "abcdefghijkl"),
        ] {
        @fs.write_file(path, prefix)
        let server = serve_raw_response(group, response)
        let result = transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          FileOutput(
            path~,
            mode=Append,
            content_disposition=false,
            remove_on_error=false,
          ),
          transfer_options(
            request_method~,
            resume_from=prefix.length().to_int64(),
            resume_skip_existing=true,
          ),
        )
        assert_eq(result.received, 0L)
        assert_eq(@fs.read_file(path).text(), prefix)
      }
    })
  })
}

///|
async test "response header failures precede output creation and differ from body EOF" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-header-eof-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      @fs.write_file(path, "preserve")
      for
        response in ["", "HTTP/1.1 200", "HTTP/1.1 200 OK\r\nContent-Length: 9"] {
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
            transfer_options(),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(context, Some(failure_context(ResponseHeaders)))
            Some(kind)
          }
          error => raise error
        } noraise {
          _ => None
        }
        assert_eq(
          failure,
          Some(if response == "" { EmptyReplyFailure } else { ReceiveFailure }),
        )
        assert_eq(@fs.read_file(path).text(), "preserve")
      }
    })
  })
}

///|
async test "resumed partial response records received and newly committed bytes separately" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-resume-count-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      @fs.write_file(path, "abc")
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nabcdef",
      )
      let failure = try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          FileOutput(
            path~,
            mode=Append,
            content_disposition=false,
            remove_on_error=false,
          ),
          transfer_options(resume_from=3L, resume_skip_existing=true),
        )
      catch {
        TransferError(kind~, context~, ..) => {
          assert_eq(kind, PartialBodyFailure)
          context
        }
        error => raise error
      } noraise {
        _ => None
      }
      assert_eq(
        failure,
        Some(
          failure_context(
            ResponseBody,
            framing=FixedLength(9L),
            received_bytes=6L,
            committed_bytes=3L,
          ),
        ),
      )
      assert_eq(@fs.read_file(path).text(), "abcdef")
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
    TransferError(..) as error =>
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
  guard failure is Some(TransferError(kind~, context~, ..)) else {
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
  let TransferError(kind~, status~, context~, ..) = failed
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
    transfer_error(PartialBodyFailure, "body ended"),
    FixedLength(12L),
    received_bytes=9L,
    committed_bytes=6L,
  )
  let TransferError(kind~, context~, ..) = read_failure
  assert_eq(kind, PartialBodyFailure)
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

///|
async test "request completion failures distinguish known phases from the combined public call" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        wire in [
          "invalid-status-line\r\n\r\n", "HTTP/2 200 OK\r\nContent-Length: 0\r\n\r\n",
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: unsupported\r\n\r\n",
        ] {
        let server = serve_raw_response(group, wire)
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            DiscardOutput,
            transfer_options(),
          )
        catch {
          TransferError(..) as error => Some(error)
          error => raise error
        } noraise {
          _ => None
        }
        guard failure is Some(TransferError(kind~, context~, ..)) else {
          fail("invalid response headers must fail")
        }
        assert_eq(kind, ReceiveFailure)
        assert_eq(context, Some(failure_context(ResponseHeaders)))
      }
      let server = serve_raw_response(group, "")
      let failure = try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          DiscardOutput,
          transfer_options(request_method=Post, headers=[
            http_header("Content-Length", "1"),
          ]),
        )
      catch {
        TransferError(..) as error => Some(error)
        error => raise error
      } noraise {
        _ => None
      }
      guard failure is Some(TransferError(kind~, context~, ..)) else {
        fail("an incomplete request body must fail")
      }
      assert_eq(kind, InputFailure)
      assert_eq(context, Some(failure_context(Request)))
    })
  })
}

///|
async test "resumed output validates ranges before mutation and can skip a repeated prefix" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-resume-range-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for
        response in [
          "HTTP/1.1 206 Partial Content\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/6\r\n\r\ndef",
          "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nabcdef",
        ] {
        @fs.write_file(path, "previous-url:abc")
        let server = serve_raw_response(group, response)
        ignore(
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Append,
              content_disposition=false,
              remove_on_error=false,
            ),
            transfer_options(resume_from=3L, resume_skip_existing=true),
          ),
        )
        assert_eq(@fs.read_file(path).text(), "previous-url:abcdef")
      }
      for
        response in [
          "HTTP/1.1 206 Partial Content\r\nContent-Length: 3\r\n\r\ndef", "HTTP/1.1 206 Partial Content\r\nContent-Length: 3\r\nContent-Range: bytes 2-4/6\r\n\r\ncde",
          "HTTP/1.1 206 Partial Content\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/5\r\n\r\ndef",
          "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nab",
        ] {
        @fs.write_file(path, "preserve:abc")
        let server = serve_raw_response(group, response)
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Append,
              content_disposition=false,
              remove_on_error=false,
            ),
            transfer_options(resume_from=3L, resume_skip_existing=true),
          )
        catch {
          TransferError(kind~, ..) => Some(kind)
          error => raise error
        } noraise {
          _ => None
        }
        assert_eq(failure, Some(ProtocolFailure))
        assert_eq(@fs.read_file(path).text(), "preserve:abc")
      }
    })
  })
}
