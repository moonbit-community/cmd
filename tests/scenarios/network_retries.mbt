///|
async fn network_retries_scenario(root : String, work : String) -> Unit {
  for
    (command, label, limited, enabled) in [
      ("curl", "retry-delay", false, true),
      ("curl", "retry-max-time", true, true),
      ("wget", "waitretry", false, true),
      ("wget", "retry-on-http-error", false, true),
      ("wget", "retry-on-http-error-control", false, false),
    ] {
    @async.with_task_group(group => {
      let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let requests : Array[Int64] = []
      group.spawn_bg(no_wait=true, () => {
        server.run_forever() <| ((request, _, connection) => {
          assert_eq(request.path, "/retry")
          requests.push(@async.now())
          let failure = if label.has_prefix("retry-on-http-error") {
            418
          } else {
            503
          }
          let code = if requests.length() == 1 { failure } else { 200 }
          connection.send_response(
            code,
            if code != 200 {
              "Unavailable"
            } else {
              "OK"
            },
            extra_headers={
              "Content-Length": if code != 200 {
                "0"
              } else {
                "5"
              },
            },
          )
          if code == 200 {
            connection.write("hello")
          }
          connection.end_response()
        })
      })
      let output = work + "/" + command + "-" + label
      let args = if command == "curl" {
        [
          "-s",
          "-f",
          "--retry",
          "2",
          "--retry-delay",
          "1",
          ..if limited {
            ["--retry-max-time", "1"]
          } else {
            []
          },
          "-o",
          output,
        ]
      } else {
        [
          "-q",
          "-t2",
          "--waitretry=0.3",
          ..if enabled {
            [
              "--retry-on-http-error=" +
              (if label.has_prefix("retry-on-http-error") {
                "418"
              } else {
                "503"
              }),
            ]
          } else {
            []
          },
          "-O",
          output,
        ]
      }
      let result = scenario_run(
        work,
        root,
        command,
        [..args, "http://127.0.0.1:\{server.addr.port()}/retry"],
        cwd=work,
        extra_env={ "NO_PROXY": "*", "no_proxy": "*" },
      )
      let retry = !limited && enabled
      let delay = if requests.length() == 2 {
        requests[1] - requests[0]
      } else {
        0L
      }
      let data = if @fs.exists(output) {
        @fs.read_file(output).text()
      } else {
        ""
      }
      let actual : Json = {
        "status": result.status,
        "stdout": @harness.scenario_text(result.stdout),
        "stderr": @harness.scenario_text(result.stderr),
        "requests": requests.length(),
        "content": data,
        "schedule": if retry {
          delay >= (if command == "curl" { 750L } else { 200L }) &&
          delay < 8000L
        } else {
          requests.length() == 1
        },
      }
      let expected : Json = {
        "status": if retry {
          0
        } else if command == "curl" {
          22
        } else {
          8
        },
        "stdout": "",
        "stderr": "",
        "requests": if retry {
          2
        } else {
          1
        },
        "content": if retry {
          "hello"
        } else {
          ""
        },
        "schedule": true,
      }
      @fs.write_file(
        work + "/../" + command + "-" + label + ".schedule.json",
        Json(requests).stringify(indent=2),
      )
      assert_eq(actual, expected)

      @harness.assert_observation(
        command + "/" + label,
        command,
        actual,
        expected,
      )
    })
  }
}

///|
async fn refused_retry_scenario(root : String, work : String) -> Unit {
  for command in ["curl", "wget"] {
    for retry in [false, true] {
      @async.with_task_group(group => {
        let reserved = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        let address = reserved.addr
        reserved.close()
        let url = "http://127.0.0.1:\{address.port()}/recover"
        let (errors, stderr) = @process.read_from_process()
        defer errors.close()
        let stdout_path = work +
          "/" +
          command +
          (if retry { "-retry" } else { "-control" }) +
          ".stdout"
        let args = if command == "curl" {
          [
            "-sS",
            "--retry",
            "1",
            "--retry-delay",
            "1",
            ..if retry {
              ["--retry-connrefused"]
            } else {
              []
            },
            url,
          ]
        } else {
          [
            "-t2",
            "--waitretry=1",
            "-O",
            "-",
            ..if retry {
              ["--retry-connrefused"]
            } else {
              []
            },
            url,
          ]
        }
        let child = @process.spawn(
          group,
          @harness.command_program(),
          @harness.command_args(root, command, args),
          cwd=work,
          stdout=@process.redirect_to_file(stdout_path),
          stderr~,
          extra_env={ "NO_PROXY": "*", "no_proxy": "*" },
          cancel_handler=@process.hard_cancel(),
        )
        let heading = if command == "wget" {
          errors.read_until("\n")
        } else {
          None
        }
        if command == "wget" {
          assert_eq(heading, Some("--  " + url))
        }
        let first = @async.with_timeout(5000, () => errors.read_until("\n"))
        guard first is Some(first) else {
          fail("missing connection-refusal acknowledgment")
        }
        assert_true(
          first.contains("connection to http://127.0.0.1:") &&
          first.to_lower().contains("refused"),
        )
        let seen = Ref(0)
        let acknowledged = @async.now()
        if retry {
          let recovered = @http.Server(address)
          group.add_defer(() => recovered.close())
          group.spawn_bg(no_wait=true, () => {
            recovered.run_forever() <| ((request, _, connection) => {
              assert_eq(request.path, "/recover")
              seen.val += 1
              connection
              ..send_response(200, "OK", extra_headers={ "Content-Length": "9" })
              ..write("recovered")
              .end_response()
            })
          })
        }
        let remaining = errors.read_all().text()
        let status = @async.with_timeout(5000, () => child.wait())
        let output = @fs.read_file(stdout_path).text()
        let elapsed = @async.now() - acknowledged
        @fs.write_file(stdout_path + ".stderr", first + "\n" + remaining)
        let actual : Json = {
          "status": status,
          "stdout": output,
          "refused": first.to_lower().contains("refused"),
          "successful_requests": seen.val,
          "retry_delay": !retry || (elapsed >= 500L && elapsed < 8000L),
        }
        let expected : Json = {
          "status": if retry {
            0
          } else if command == "curl" {
            7
          } else {
            4
          },
          "stdout": if retry {
            "recovered"
          } else {
            ""
          },
          "refused": true,
          "successful_requests": if retry {
            1
          } else {
            0
          },
          "retry_delay": true,
        }
        assert_eq(actual, expected)

        @harness.assert_observation(
          command + "/refused-" + (if retry { "retry" } else { "control" }),
          command,
          actual,
          expected,
        )
      })
    }
  }
}
