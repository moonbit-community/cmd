///|
async fn curl_output_retry_fixture(
  group : @async.TaskGroup[Unit],
  responses : Array[String],
  output : String,
  before_response : Array[Bytes?],
) -> @socket.TcpServer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  group.add_defer(() => server.close())
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((connection, _) => {
      while connection.read_until("\r\n") is Some(line) && line != "" {
        ()
      }
      let ordinal = before_response.length()
      before_response.push(
        if @fs.exists(output) {
          Some(@fs.read_file(output).binary())
        } else {
          None
        },
      )
      guard responses.get(ordinal) is Some(response) else {
        fail("unexpected request after the supplied response sequence")
      }
      if response != "" {
        connection.write(response)
      }
    })
  })
  server
}

///|
fn curl_output_retry_options() -> CurlOptions {
  let options = default_curl_options()
  options.silent = true
  options.no_proxy = Some("*")
  options.retry_count = 1
  options.retry_all_errors = true
  options.retry_delay_ms = 1
  options
}

///|
async test "curl accepted retries reset opened files before a later empty failure" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="curl-retry-empty-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for existing in [false, true] {
        for remove_on_error in [false, true] {
          for no_headers in [false, true] {
            let path = directory +
              "/\{existing}-\{remove_on_error}-\{no_headers}"
            if existing {
              @fs.write_file(path, b"preserve")
            }
            let before : Array[Bytes?] = []
            let server = curl_output_retry_fixture(
              group,
              [
                "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nhello",
                if no_headers {
                  ""
                } else {
                  "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n"
                },
              ],
              path,
              before,
            )
            let options = curl_output_retry_options()
            options.output_specs.push(path)
            options.remove_on_error = remove_on_error
            let status = curl_transfer_one(
              options,
              "http://127.0.0.1:\{server.addr.port()}/body",
              0,
              None,
            )
            assert_eq(status, if no_headers { 52 } else { 18 })
            assert_eq(before, [
              if existing {
                Some(b"preserve")
              } else {
                None
              },
              Some(b""),
            ])
            assert_eq(@fs.exists(path), !remove_on_error)
            if !remove_on_error {
              assert_eq(@fs.read_file(path).binary(), b"")
            }
          }
        }
      }
    })
  })
}

///|
async test "curl leaves partial files intact when a retry is not accepted" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="curl-retry-refused-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for exhausted_budget in [false, true] {
        let path = directory + "/\{exhausted_budget}"
        let before : Array[Bytes?] = []
        let server = curl_output_retry_fixture(
          group,
          ["HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nhello"],
          path,
          before,
        )
        let options = curl_output_retry_options()
        options.output_specs.push(path)
        if exhausted_budget {
          options.retry_max_time_ms = Some(1)
          options.retry_delay_ms = 10
        } else {
          options.retry_count = 0
        }
        assert_eq(
          curl_transfer_one(
            options,
            "http://127.0.0.1:\{server.addr.port()}/body",
            0,
            None,
          ),
          18,
        )
        assert_eq(before, [None])
        assert_eq(@fs.read_file(path).binary(), b"hello")
      }
    })
  })
}

///|
async test "curl first empty failures preserve unopened files with final cleanup enabled" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="curl-first-empty-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      for existing in [false, true] {
        let path = directory + "/\{existing}"
        if existing {
          @fs.write_file(path, b"preserve")
        }
        let before : Array[Bytes?] = []
        let server = curl_output_retry_fixture(
          group,
          ["HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n"],
          path,
          before,
        )
        let options = curl_output_retry_options()
        options.output_specs.push(path)
        options.retry_count = 0
        options.remove_on_error = true
        assert_eq(
          curl_transfer_one(
            options,
            "http://127.0.0.1:\{server.addr.port()}/body",
            0,
            None,
          ),
          18,
        )
        assert_eq(before.length(), 1)
        assert_eq(@fs.exists(path), existing)
        if existing {
          assert_eq(@fs.read_file(path).binary(), b"preserve")
        }
      }
    })
  })
}

///|
async test "curl retries retain the selected content disposition path and defer removal" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let token = @async.now().to_string()
      for remove_on_error in [false, true] {
        for ending in ["empty", "changed", "missing"] {
          let first = "curl-retry-cd-\{token}-\{remove_on_error}-\{ending}.bin"
          let second = first + ".second"
          let fallback = first + ".url"
          defer @async.protect_from_cancel(() => {
            for path in [first, second, fallback] {
              if @fs.exists(path) {
                @fs.remove(path)
              }
            }
          })
          let before : Array[Bytes?] = []
          let disposition = if ending == "missing" {
            ""
          } else {
            "Content-Disposition: attachment; filename=\"\{second}\"\r\n"
          }
          let server = curl_output_retry_fixture(
            group,
            [
              "HTTP/1.1 200 OK\r\nContent-Disposition: attachment; filename=\"\{first}\"\r\nContent-Length: 9\r\n\r\nhello",
              "HTTP/1.1 200 OK\r\n" +
              disposition +
              (if ending == "empty" {
                "Content-Length: 9\r\n\r\n"
              } else {
                "Content-Length: 2\r\n\r\nok"
              }),
            ],
            first,
            before,
          )
          let options = curl_output_retry_options()
          options.remote_name = true
          options.remote_header_name = true
          options.remove_on_error = remove_on_error
          assert_eq(
            curl_transfer_one(
              options,
              "http://127.0.0.1:\{server.addr.port()}/" + fallback,
              0,
              None,
            ),
            if ending == "empty" {
              18
            } else {
              0
            },
          )
          assert_eq(before, [None, Some(b"")])
          assert_false(@fs.exists(second))
          assert_false(@fs.exists(fallback))
          if ending == "empty" && remove_on_error {
            assert_false(@fs.exists(first))
          } else {
            assert_eq(
              @fs.read_file(first).binary(),
              if ending == "empty" {
                b""
              } else {
                b"ok"
              },
            )
          }
        }
      }
    })
  })
}
