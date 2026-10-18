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

///|
async test "curl content disposition creates exclusive output before empty body failures" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let token = @async.now().to_string()
      for profile in [StrictProfile, CurlProfile, WgetProfile] {
        for existing in [false, true] {
          let suffix = if profile == StrictProfile {
            "strict"
          } else if profile == CurlProfile {
            "curl"
          } else {
            "wget"
          }
          let path = "netops-cd-empty-\{token}-\{suffix}-\{existing}.bin"
          defer @async.protect_from_cancel(() => {
            if @fs.exists(path) {
              @fs.remove(path)
            }
          })
          if existing {
            @fs.write_file(path, b"preserve")
          }
          let server = serve_raw_response(
            group,
            "HTTP/1.1 200 OK\r\nContent-Disposition: attachment; filename=\"\{path}\"\r\nContent-Length: 9\r\n\r\n",
          )
          let opened : Array[String?] = []
          try
            transfer(
              "http://127.0.0.1:\{server.addr.port()}/body",
              FileOutput(
                path=path + ".fallback",
                mode=Truncate,
                content_disposition=true,
                remove_on_error=false,
              ),
              transfer_options(profile~),
              observer=event => {
                if event is OutputStarted(path~, ..) {
                  opened.push(path)
                }
              },
            )
          catch {
            TransferError(kind~, ..) =>
              assert_eq(
                kind,
                if profile == CurlProfile && existing {
                  OutputFailure
                } else {
                  PartialBodyFailure
                },
              )
            error => raise error
          } noraise {
            _ =>
              fail(
                "an incomplete body or an existing curl destination must fail",
              )
          }
          assert_eq(
            opened,
            if profile == CurlProfile && existing {
              []
            } else {
              [Some(path)]
            },
          )
          assert_eq(
            @fs.read_file(path).binary(),
            if profile == CurlProfile && existing {
              b"preserve"
            } else {
              b""
            },
          )
          assert_false(@fs.exists(path + ".fallback"))
        }
      }
    })
  })
}

///|
async test "curl content disposition selection follows response status and fail policy" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let token = @async.now().to_string()
      for status in [200, 304, 404, 500] {
        for framing in ["empty", "partial", "complete"] {
          for fail_on_http_error in [false, true] {
            let stem = "netops-cd-status-\{token}-\{status}-\{framing}-\{fail_on_http_error}"
            let selected = stem + ".selected"
            let fallback = stem + ".url"
            defer @async.protect_from_cancel(() => {
              for path in [selected, fallback] {
                if @fs.exists(path) {
                  @fs.remove(path)
                }
              }
            })
            let payload = if framing == "complete" { "hello" } else { "" }
            let length = if framing == "partial" { 9 } else { payload.length() }
            let server = serve_raw_response(
              group,
              "HTTP/1.1 \{status} Fixture\r\nContent-Disposition: attachment; filename=\"\{selected}\"\r\nContent-Length: \{length}\r\n\r\n" +
              payload,
            )
            let opened : Array[String?] = []
            let failure = try
              transfer(
                "http://127.0.0.1:\{server.addr.port()}/" + fallback,
                FileOutput(
                  path=fallback,
                  mode=Truncate,
                  content_disposition=true,
                  remove_on_error=false,
                ),
                transfer_options(profile=CurlProfile, fail_on_http_error~),
                observer=event => {
                  if event is OutputStarted(path~, ..) {
                    opened.push(path)
                  }
                },
              )
            catch {
              TransferError(kind~, ..) => Some(kind)
              error => raise error
            } noraise {
              result => {
                assert_eq(result.status, status)
                assert_eq(
                  result.received,
                  if status == 304 {
                    0L
                  } else {
                    payload.length().to_int64()
                  },
                )
                None
              }
            }
            let http_failure = fail_on_http_error && status >= 400
            let partial_failure = status != 304 && framing == "partial"
            assert_eq(
              failure,
              if http_failure {
                Some(HttpStatusFailure)
              } else if partial_failure {
                Some(PartialBodyFailure)
              } else {
                None
              },
            )
            let use_disposition = status < 400
            let creates_output = !http_failure &&
              (use_disposition || !partial_failure)
            let chosen = if use_disposition { selected } else { fallback }
            let untouched = if use_disposition { fallback } else { selected }
            assert_false(@fs.exists(untouched))
            assert_eq(@fs.exists(chosen), creates_output)
            assert_eq(opened, if creates_output { [Some(chosen)] } else { [] })
            if creates_output {
              assert_eq(
                @fs.read_file(chosen).text(),
                if status == 304 {
                  ""
                } else {
                  payload
                },
              )
            }
          }
        }
      }
      for profile in [StrictProfile, WgetProfile] {
        let suffix = if profile == StrictProfile { "strict" } else { "wget" }
        let selected = "netops-cd-status-\{token}-\{suffix}.selected"
        let fallback = selected + ".url"
        defer @async.protect_from_cancel(() => {
          for path in [selected, fallback] {
            if @fs.exists(path) {
              @fs.remove(path)
            }
          }
        })
        let server = serve_raw_response(
          group,
          "HTTP/1.1 404 Not Found\r\nContent-Disposition: attachment; filename=\"\{selected}\"\r\nContent-Length: 5\r\n\r\nhello",
        )
        let result = transfer(
          "http://127.0.0.1:\{server.addr.port()}/" + fallback,
          FileOutput(
            path=fallback,
            mode=Truncate,
            content_disposition=true,
            remove_on_error=false,
          ),
          transfer_options(profile~),
        )
        assert_eq(result.output_path, Some(selected))
        assert_eq(@fs.read_file(selected).binary(), b"hello")
        assert_false(@fs.exists(fallback))
      }
    })
  })
}
