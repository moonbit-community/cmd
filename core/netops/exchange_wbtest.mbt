///|
fn exchange_test_transport() -> Transport {
  {
    proxy: None,
    verify_tls: true,
    connect_timeout_ms: 1000,
    idle_timeout_ms: 1000,
    deadline_ms: None,
  }
}

///|
fn exchange_test_request(port : Int32) -> Request {
  let target = parse_absolute_url("http://127.0.0.1:\{port}/") catch {
    _ => abort("invalid fixture URL")
  }
  {
    target,
    host: target.endpoint,
    request_method: Get,
    headers: [],
    body: EmptyBody,
  }
}

///|
async fn read_test_response(port : Int32) -> Int64 {
  with_response(exchange_test_request(port), exchange_test_transport(), scope => {
    let mut count = 0L
    for ;; {
      match scope.read() {
        Data(bytes) => count += bytes.length().to_int64()
        End => break
        Incomplete(_) => fail("fixture must have complete body framing")
      }
    }
    count
  })
}

///|
async test "response scope exposes the exact incomplete framing boundary and delivered bytes" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        (body, expected, boundary) in [
          ("", b"", "size"),
          ("5\r\n", b"", "payload"),
          ("9\r\nhello", b"hello", "payload"),
          ("5\r\nhello", b"hello", "separator"),
          ("5\r\nhello\r\n", b"hello", "size"),
          ("5\r\nhello\r\n0\r\nX-Trailer: yes\r\n", b"hello", "trailers"),
        ] {
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + body,
        )
        with_response(
          exchange_test_request(server.addr.port()),
          exchange_test_transport(),
          scope => {
            let delivered = Buffer()
            for ;; {
              match scope.read(max_len=2) {
                Data(bytes) => {
                  assert_true(bytes.length() <= 2)
                  delivered.write_bytes(bytes)
                }
                End =>
                  fail(
                    "truncated fixture must retain an incomplete framing observation",
                  )
                Incomplete(actual) => {
                  let actual = match actual {
                    FixedPayload => "fixed"
                    ChunkPayload => "payload"
                    ChunkSizeLine => "size"
                    ChunkSeparatorBytes => "separator"
                    TrailerFields => "trailers"
                  }
                  assert_eq(actual, boundary)
                  assert_eq(delivered.to_bytes(), expected)
                  break
                }
              }
            }
          },
        )
      }
    })
  })
}

///|
async test "incomplete headers expose only complete fields without command acceptance policy" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for
        wire in [
          "HTTP/1.1 200 OK\r\nContent-Length: 1", "HTTP/1.1 200 OK\r\nContent-Length: 9",
        ] {
        let server = serve_raw_response(group, wire)
        with_response(
          exchange_test_request(server.addr.port()),
          exchange_test_transport(),
          scope => {
            assert_false(scope.head().complete)
            assert_eq(scope.head().code, 200)
            assert_eq(scope.head().fields, [])
          },
        )
      }
      for code in [200, 404] {
        let server = serve_raw_response(
          group,
          "HTTP/1.1 \{code} Result\r\nX-Complete: yes\r\nContent-Len",
        )
        with_response(
          exchange_test_request(server.addr.port()),
          exchange_test_transport(),
          scope => {
            let head = scope.head()
            assert_eq(head.code, code)
            assert_false(head.complete)
            assert_eq(head.fields, [http_header("X-Complete", "yes")])
          },
        )
      }
    })
  })
}

///|
priv suberror ExchangeConsumerFailure {
  ExchangeConsumerFailure
}

///|
async test "request and header failures retain completed upload byte counts" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for declared in [8, 3] {
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        group.add_defer(() => server.close())
        let received = group.spawn(() => {
          let (connection, _) = server.accept()
          defer connection.close()
          while connection.read_until("\r\n") is Some(line) && line != "" {
            ()
          }
          let bytes = connection.read_exactly(3)
          if declared == 3 {
            connection.write("invalid-status-line\r\n\r\n")
          }
          assert_true(connection.read_some() is None)
          bytes
        })
        let request = {
          ..exchange_test_request(server.addr.port()),
          request_method: Post,
          headers: [http_header("Content-Length", declared.to_string())],
          body: BytesBody(b"abc"),
        }
        let consume : async (ResponseScope) -> Unit = _ => {
          fail("invalid exchange reached the consumer")
        }
        try with_response(request, exchange_test_transport(), consume) catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(
              kind,
              if declared == 8 {
                InputFailure
              } else {
                ReceiveFailure
              },
            )
            assert_eq(
              context,
              Some(
                failure_context(
                  if declared == 8 {
                    Request
                  } else {
                    ResponseHeaders
                  },
                  sent_bytes=3L,
                ),
              ),
            )
          }
          error => raise error
        } noraise {
          _ => fail("invalid exchange succeeded")
        }
        assert_eq(received.wait(), b"abc")
      }
    })
  })
}

///|
async test "body read errors retain framing and delivered byte counts" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\nbad trailer\r\n\r\n",
      )
      with_response(
        exchange_test_request(server.addr.port()),
        exchange_test_transport(),
        scope => {
          let body = Buffer()
          try {
            for ;; {
              match scope.read(max_len=2) {
                Data(bytes) => body.write_bytes(bytes)
                _ => fail("malformed trailer must fail")
              }
            }
          } catch {
            TransferError(kind~, context~, ..) => {
              assert_eq(kind, ReceiveFailure)
              assert_eq(
                context,
                Some(
                  failure_context(
                    ResponseBody,
                    framing=Chunked,
                    received_bytes=5L,
                  ),
                ),
              )
            }
            error => raise error
          }
          assert_eq(body.to_bytes(), b"hello")
        },
      )
    })
  })
}

///|
async test "response scope closes the connection on return error and cancellation" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      for mode in [0, 1, 2] {
        let changed = @cond_var.Cond()
        let entered = Ref(false)
        let closed = Ref(false)
        let escaped : Ref[ResponseScope?] = Ref(None)
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        group.add_defer(() => server.close())
        group.spawn_bg(no_wait=true, () => {
          server.run_forever((connection, _) => {
            while connection.read_until("\r\n") is Some(line) && line != "" {
              ()
            }
            connection.write(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
            assert_true(connection.read_some() is None)
            closed.val = true
            changed.signal()
          })
        })
        let task = group.spawn(() => {
          @async.handle_cancellation(() => {
            with_response(
              exchange_test_request(server.addr.port()),
              exchange_test_transport(),
              scope => {
                escaped.val = Some(scope)
                entered.val = true
                changed.signal()
                if mode == 1 {
                  raise ExchangeConsumerFailure
                }
                if mode == 2 {
                  @async.sleep(10000)
                }
              },
            ) catch {
              ExchangeConsumerFailure => ()
              error => raise error
            }
          })
        })
        while !entered.val {
          changed.wait()
        }
        if mode == 2 {
          task.cancel()
        }
        ignore(task.wait())
        while !closed.val {
          changed.wait()
        }
        try escaped.val.unwrap().read() catch {
          TransferError(kind~, ..) => assert_eq(kind, ReceiveFailure)
          error => raise error
        } noraise {
          _ => fail("an escaped response scope must already be closed")
        }
      }
    })
  })
}
