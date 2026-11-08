///|
async fn check_transfer_files(
  work : String,
  files : Array[(String, String?)],
  observed_names : Array[String],
) -> Unit {
  let expected_names : Array[String] = []
  for (name, content) in files {
    if content is Some(_) {
      expected_names.push(name)
    }
  }
  expected_names.sort()
  let names = observed_names.copy()
  names.sort()
  let failures : Array[String] = []
  if names != expected_names {
    failures.push(
      "transfer output file set differs: " +
      repr(names) +
      " != " +
      repr(expected_names),
    )
  }
  for (name, content) in files {
    let path = work + "/" + name
    try {
      match content {
        Some(content) => {
          assert_true(@fs.exists(path), msg="missing transfer output: " + name)
          assert_eq(
            @fs.kind(path, follow_symlink=false),
            @fs.Regular,
            msg="transfer output must be a regular file: " + name,
          )
          assert_eq(@fs.read_file(path).binary(), @utf8.encode(content))
        }
        None =>
          assert_false(
            @fs.exists(path),
            msg="unexpected transfer output: " + name,
          )
      }
    } catch {
      error => failures.push(name + ": " + error.to_string())
    }
  }
  guard failures.is_empty() else { fail(failures.join("; ")) }
}

///|
// Exact statuses observed with pinned-oracle-v1 image
// sha256:05e320ad56f11fc1207b0946b414468b90fc0c8bf8e65d32eb2ba48f682589b7.
fn transfer_oracle_status(command : String, label : String) -> Int32 raise {
  if command == "curl" || command == "wget" {
    for part in ["path", "query"] {
      for character in ["space", "tab", "cr", "lf", "del"] {
        for form in ["raw", "escaped"] {
          if label == "wire-url-\{part}-\{character}-\{form}" {
            return if command == "curl" && form == "raw" { 3 } else { 0 }
          }
        }
      }
      if label == "wire-url-\{part}-escaped-crlf" {
        return 0
      }
      for character in ["space", "tab", "escaped-crlf"] {
        if label == "wire-redirect-\{part}-\{character}" {
          return 0
        }
      }
    }
    for
      cookie in [
        "no-pair", "invalid-maxage", "seeded-invalid-maxage", "duplicate-valid-invalid",
        "duplicate-invalid-valid", "no-pair-disabled", "invalid-maxage-disabled",
        "order-name-length", "order-equal-length", "order-equal-reverse", "order-replace",
        "order-invalid-valid-cross", "maxage-overflow-one", "maxage-overflow-many",
      ] {
      if label == "wire-cookie-" + cookie {
        return 0
      }
    }
  }
  match command {
    "curl" =>
      match label {
        "chunk-complete"
        | "close-complete"
        | "empty-complete"
        | "empty-output-complete-new-keep"
        | "empty-output-complete-new-remove"
        | "empty-output-complete-existing-keep"
        | "empty-output-complete-existing-remove"
        | "stdin-retry-256"
        | "stdin-retry-65537"
        | "stdin-retry-show-error-256"
        | "remove-partial-complete-new"
        | "cd-partial-complete-changed"
        | "cd-partial-complete-missing"
        | "cd-partial-complete-changed-remove"
        | "cd-status-200-empty-complete-fail-false"
        | "cd-status-200-empty-complete-fail-true"
        | "cd-status-200-body-complete-fail-false"
        | "cd-status-200-body-complete-fail-true"
        | "cd-status-304-empty-complete-fail-false"
        | "cd-status-304-empty-complete-fail-true"
        | "cd-status-304-empty-incomplete-fail-false"
        | "cd-status-304-empty-incomplete-fail-true"
        | "cd-status-304-body-complete-fail-false"
        | "cd-status-304-body-complete-fail-true"
        | "cd-status-404-empty-complete-fail-false"
        | "cd-status-404-body-complete-fail-false"
        | "cd-status-500-empty-complete-fail-false"
        | "cd-status-500-body-complete-fail-false"
        | "fixed-complete"
        | "fixed-prefix-then-fixed-complete"
        | "head-length"
        | "header-partial-file"
        | "header-partial"
        | "no-content"
        | "not-modified"
        | "output-full-empty"
        | "output-null-complete"
        | "trailer-complete" => 0
        "chunk-data-crlf"
        | "chunk-initial-eof"
        | "chunk-empty"
        | "chunk-payload-file"
        | "chunk-payload"
        | "chunk-terminator-file"
        | "chunk-terminator"
        | "chunk-trailer"
        | "default-retry-does-not-retry-partial"
        | "fixed-complete-then-fixed-prefix"
        | "fixed-empty-file"
        | "fixed-empty"
        | "empty-output-partial-new-keep"
        | "empty-output-partial-new-remove"
        | "empty-output-partial-existing-keep"
        | "empty-output-partial-existing-remove"
        | "fixed-prefix-existing-file"
        | "fixed-prefix-file"
        | "fixed-prefix"
        | "keep-named"
        | "output-full-partial"
        | "output-full-partial-4095"
        | "remove-named"
        | "remove-partial"
        | "retry-all-file"
        | "retry-all-stdout"
        | "retry-partial-empty-file-new"
        | "retry-partial-empty-file-existing"
        | "retry-partial-empty-stdout"
        | "remove-partial-empty-new"
        | "remove-partial-empty-existing"
        | "cd-partial-empty-changed"
        | "cd-partial-empty-changed-remove"
        | "cd-first-empty-new"
        | "cd-status-200-empty-incomplete-fail-false"
        | "cd-status-200-empty-incomplete-fail-true"
        | "cd-status-404-empty-incomplete-fail-false"
        | "cd-status-500-empty-incomplete-fail-false" => 18
        "cd-status-404-empty-complete-fail-true"
        | "cd-status-404-empty-incomplete-fail-true"
        | "cd-status-404-body-complete-fail-true"
        | "cd-status-500-empty-complete-fail-true"
        | "cd-status-500-empty-incomplete-fail-true"
        | "cd-status-500-body-complete-fail-true" => 22
        "cd-first-empty-existing"
        | "output-full-complete"
        | "output-full-complete-4095"
        | "output-full-complete-4096"
        | "output-full-partial-4096" => 23
        "header-empty-existing-file" | "header-empty-file" | "header-empty" =>
          52
        "chunk-invalid" => 56
        "stdin-redirect-307" => 65
        _ => fail("missing frozen oracle status: " + command + " " + label)
      }
    "wget" =>
      match label {
        "chunk-complete"
        | "chunk-empty"
        | "chunk-payload-file"
        | "chunk-payload"
        | "chunk-trailer"
        | "close-complete"
        | "empty-complete"
        | "fixed-complete"
        | "head-length"
        | "header-partial-file"
        | "header-partial"
        | "no-content"
        | "output-full-empty"
        | "output-null-complete"
        | "resume-name-change-ignore-existing"
        | "resume-name-change-ignore-new"
        | "resume-nonfinal-range"
        | "resume-unsatisfied-equal-resource"
        | "resume-unsatisfied-longer-than-resource"
        | "resume-unsatisfied-shorter-than-resource"
        | "resume-unsatisfied-malformed-local-3"
        | "resume-unsatisfied-malformed-local-6"
        | "resume-unsatisfied-malformed-local-7"
        | "resume-unsatisfied-missing-local-3"
        | "resume-unsatisfied-missing-local-6"
        | "resume-unsatisfied-missing-local-7"
        | "resume-unsatisfied-without-resume"
        | "resume-named-valid-new"
        | "resume-named-valid-existing"
        | "retry-content-disposition-keeps-actual-name"
        | "retry-ignore-aggregate"
        | "retry-ignore-changed-aggregate"
        | "retry-ignore-changed-default-file"
        | "retry-ignore-changed-file"
        | "retry-ignore-changed-stdout"
        | "retry-ignore-default-file"
        | "retry-ignore-file"
        | "retry-ignore-stdout"
        | "retry-range-aggregate"
        | "retry-range-default-file"
        | "retry-range-file"
        | "retry-range-stdout"
        | "retry-unique-keeps-actual-name"
        | "trailer-complete" => 0
        "output-full-complete" | "output-full-partial" => 3
        "chunk-data-crlf"
        | "chunk-initial-eof"
        | "chunk-invalid"
        | "chunk-terminator-file"
        | "chunk-terminator"
        | "fixed-complete-then-fixed-prefix"
        | "fixed-empty-file"
        | "fixed-empty"
        | "fixed-prefix-existing-file"
        | "fixed-prefix-file"
        | "fixed-prefix-then-fixed-complete"
        | "fixed-prefix"
        | "header-empty-existing-file"
        | "header-empty-file"
        | "header-empty"
        | "resume-name-change-existing"
        | "resume-name-change-new"
        | "retry-empty-is-bounded"
        | "retry-wrong-range-preserves-prefix" => 4
        "not-modified" => 8
        _ => fail("missing frozen oracle status: " + command + " " + label)
      }
    _ => fail("unknown transfer command: " + command)
  }
}

///|
async fn transfer_scenario_call(
  executor : Executor,
  work : String,
  command : String,
  label : String,
  args : Array[String],
  stdout : String,
  ranges : Array[String?],
  requests : Array[@harness.TransferFixtureRequest],
  oracle_failures : Array[String],
  files~ : Array[(String, String?)] = [],
  initial_files~ : Array[(String, String)] = [],
  stdin~ : Bytes = b"",
  expected_stderr~ : String = "",
  bodies? : Array[Bytes],
  methods? : Array[String],
  request_wires? : Array[Bytes],
  paths? : Array[String],
  cookies? : Array[Array[String]],
  transfer_files? : TransferFileObservation,
  expected_files_before_response? : Array[Array[(String, String)]],
  oracle_image? : String,
) -> Unit {
  try {
    let case_work = work + "/" + command + "-" + label
    @fs.mkdir(case_work)
    for (name, content) in initial_files {
      @fs.write_file(case_work + "/" + name, content)
    }
    if oracle_image is Some(_) {
      @fs.mkdir(case_work + "/oracle")
      for (name, content) in initial_files {
        @fs.write_file(case_work + "/oracle/" + name, content)
      }
    }
    let call_failures : Array[String] = []
    let expected_methods = methods.unwrap_or(ranges.map(_ => "GET"))
    let result = network_request(
      executor,
      case_work,
      command,
      args,
      stdin~,
      oracle_image?,
      oracle_failures=call_failures,
      transfer_requests=requests,
      request_wires?,
      expected_paths?=paths,
      expected_cookies?=cookies,
      expected_ranges=ranges,
      expected_methods~,
      expected_bodies?=bodies,
      expected_files=files,
      transfer_files?,
      expected_files_before_response?,
    )
    if result.stdout != @utf8.encode(stdout) {
      call_failures.push(
        "candidate stdout bytes differ from the scenario contract",
      )
    }
    if result.stderr != @utf8.encode(expected_stderr) {
      call_failures.push(
        "candidate stderr bytes differ from the scenario contract",
      )
    }
    let expected_status = transfer_oracle_status(command, label)
    if oracle_image is None &&
      executor.proof is Some(proof) &&
      proof.accepts("transfer/" + command + "-" + label + "/response", command) {
      proof.observe_equal(
        "transfer/" + command + "-" + label + "/response",
        command,
        {
          "status": result.status,
          "stdout": @harness.scenario_text(result.stdout),
          "stderr": @harness.scenario_text(result.stderr),
        },
        {
          "status": expected_status,
          "stdout": stdout,
          "stderr": expected_stderr,
        },
      )
    }
    if result.status != expected_status {
      call_failures.push(
        "candidate status " +
        result.status.to_string() +
        " != frozen oracle status " +
        expected_status.to_string(),
      )
    }
    @fs.write_file(
      case_work + "/contract-checks.json",
      @harness.canonical_json({
        "command": Json(command),
        "label": Json(label),
        "status": Json(result.status),
        "status_contract": Json("exact-pinned-oracle-calibration"),
        "expected_status": Json(expected_status),
        "expected_stdout": Json(stdout),
        "expected_stderr": Json(expected_stderr),
        "expected_files_before_response": expected_files_before_response
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_methods": Json(expected_methods),
        "expected_paths": paths
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_cookies": cookies
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_bodies": bodies
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_ranges": Json(
          ranges.map(range => {
            range.map(value => Json(value)).unwrap_or(Json::null())
          }),
        ),
        "failures": Json(call_failures),
      }),
    )
    oracle_failures.append(
      call_failures.map(error => command + " " + label + ": " + error),
    )
  } catch {
    error =>
      oracle_failures.push(command + " " + label + ": " + error.to_string())
  }
}

///|
/// Range and upload fixtures are stateless. The retry lifecycle sequences use the
/// request capture reset before each candidate and oracle execution.
async fn network_transfer_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let oracle_failures : Array[String] = []
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[@harness.TransferFixtureRequest] = []
    let transfer_files : TransferFileObservation = {
      work: None,
      evidence_name: None,
      snapshots: [],
    }
    group.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, _, connection) => {
        if !@harness.serve_transfer_fixture(request, connection, requests~, before_response=() => {
            transfer_files.capture()
          }) {
          fail("unknown transfer fixture path: " + request.path)
        }
      })
    })
    let base = "http://127.0.0.1:\{server.addr.port()}"
    @fs.write_file(work + "/../network-origin.txt", base)
    for command in ["curl", "wget"] {
      let quiet = if command == "curl" { ["-s"] } else { ["-q", "-t", "1"] }
      let to_stdout = if command == "curl" { [] } else { ["-O", "-"] }
      for
        (endpoint, stdout) in [
          ("fixed-empty", ""),
          ("fixed-prefix", "hello"),
          ("chunk-empty", ""),
          ("chunk-initial-eof", ""),
          ("chunk-payload", "hello"),
          ("chunk-data-crlf", "hello"),
          ("chunk-terminator", "hello"),
          ("chunk-trailer", "hello"),
          ("chunk-invalid", ""),
          ("header-empty", ""),
          ("header-partial", ""),
          ("fixed-complete", "hello"),
          ("chunk-complete", "hello"),
          ("trailer-complete", "hello"),
          ("close-complete", "hello"),
          ("empty-complete", ""),
          ("no-content", ""),
          ("not-modified", ""),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint,
          [
            ..quiet,
            ..if command == "wget" && endpoint == "fixed-empty" {
              ["--waitretry=0.001"]
            } else {
              []
            },
            ..to_stdout,
            base + "/transfer-" + endpoint,
          ],
          stdout,
          [None],
          requests,
          oracle_failures,
          oracle_image?,
        )
      }
      transfer_scenario_call(
        executor,
        work,
        command,
        "head-length",
        [
          ..quiet,
          ..to_stdout,
          if command == "curl" {
            "-I"
          } else {
            "--method=HEAD"
          },
          base + "/transfer-head-length",
        ],
        if command == "curl" {
          "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n"
        } else {
          ""
        },
        [None],
        requests,
        oracle_failures,
        methods=["HEAD"],
        oracle_image?,
      )
      if @async.platform is Linux {
        for device in ["/dev/full", "/dev/null"] {
          guard @fs.kind(device, follow_symlink=false) == @fs.CharDevice else {
            fail(
              "infrastructure: output observation requires a character device: " +
              device,
            )
          }
        }
        for
          (label, endpoint, output) in [
            ("output-full-complete", "fixed-complete", "/dev/full"),
            ("output-full-partial", "fixed-prefix", "/dev/full"),
            ("output-full-empty", "empty-complete", "/dev/full"),
            ("output-null-complete", "fixed-complete", "/dev/null"),
          ] {
          transfer_scenario_call(
            executor,
            work,
            command,
            label,
            [
              ..quiet,
              if command == "curl" {
                "-o"
              } else {
                "-O"
              },
              output,
              base + "/transfer-" + endpoint,
            ],
            "",
            [None],
            requests,
            oracle_failures,
            oracle_image?,
          )
        }
        if command == "curl" {
          for count in [4095, 4096] {
            for completion in ["partial", "complete"] {
              transfer_scenario_call(
                executor,
                work,
                command,
                "output-full-\{completion}-\{count}",
                [
                  "-s",
                  "-o",
                  "/dev/full",
                  base + "/transfer-output-\{completion}-\{count}",
                ],
                "",
                [None],
                requests,
                oracle_failures,
                oracle_image?,
              )
            }
          }
        }
      }
      for endpoint in ["fixed-prefix", "chunk-payload", "chunk-terminator"] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint + "-file",
          [
            ..quiet,
            if command == "curl" {
              "-o"
            } else {
              "-O"
            },
            "partial.bin",
            base + "/transfer-" + endpoint,
          ],
          "",
          [None],
          requests,
          oracle_failures,
          files=[("partial.bin", Some("hello"))],
          oracle_image?,
        )
      }
      for
        (endpoint, content) in [
          ("fixed-empty", if command == "curl" { None } else { Some("") }),
          ("header-empty", if command == "curl" { None } else { Some("") }),
          ("header-partial", Some("")),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint + "-file",
          [
            ..quiet,
            if command == "curl" {
              "-o"
            } else {
              "-O"
            },
            "partial.bin",
            base + "/transfer-" + endpoint,
          ],
          "",
          [None],
          requests,
          oracle_failures,
          files=[("partial.bin", content)],
          oracle_image?,
        )
      }
      for
        (endpoint, content) in [
          ("fixed-prefix", "hello"),
          ("header-empty", if command == "curl" { "original" } else { "" }),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint + "-existing-file",
          [
            ..quiet,
            if command == "curl" {
              "-o"
            } else {
              "-O"
            },
            "partial.bin",
            base + "/transfer-" + endpoint,
          ],
          "",
          [None],
          requests,
          oracle_failures,
          initial_files=[("partial.bin", "original")],
          files=[("partial.bin", Some(content))],
          oracle_image?,
        )
      }
      for
        (first, second) in [
          ("fixed-prefix", "fixed-complete"),
          ("fixed-complete", "fixed-prefix"),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          first + "-then-" + second,
          [
            ..quiet,
            ..to_stdout,
            base + "/transfer-" + first,
            base + "/transfer-" + second,
          ],
          "hellohello",
          [None, None],
          requests,
          oracle_failures,
          oracle_image?,
        )
      }
    }
    for count in [256, 65537] {
      let input = Bytes::from_array(
        Array::makei(count, index => (index % 256).to_byte()),
      )
      transfer_scenario_call(
        executor,
        work,
        "curl",
        "stdin-retry-\{count}",
        [
          "-s",
          "-T",
          "-",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          base + "/transfer-stdin-retry",
        ],
        "hellook",
        [None, None],
        requests,
        oracle_failures,
        stdin=input,
        bodies=[input, b""],
        methods=["PUT", "PUT"],
        oracle_image?,
      )
    }
    let binary_input = Bytes::from_array(
      Array::makei(256, index => index.to_byte()),
    )
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "stdin-retry-show-error-256",
      [
        "-sS",
        "-T",
        "-",
        "--retry",
        "1",
        "--retry-all-errors",
        "--retry-delay",
        "1",
        base + "/transfer-stdin-retry",
      ],
      "hellook",
      [None, None],
      requests,
      oracle_failures,
      stdin=binary_input,
      expected_stderr="curl: (18) end of response with 4 bytes missing\n",
      bodies=[binary_input, b""],
      methods=["PUT", "PUT"],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "stdin-redirect-307",
      [
        "-s",
        "-T",
        "-",
        "-L",
        "--max-redirs",
        "2",
        base + "/transfer-stdin-redirect",
      ],
      "",
      [None],
      requests,
      oracle_failures,
      stdin=binary_input,
      bodies=[binary_input],
      methods=["PUT"],
      oracle_image?,
    )
    for existing in [false, true] {
      for remove in [false, true] {
        for complete in [false, true] {
          let completion = if complete { "complete" } else { "partial" }
          let prior = if existing { "existing" } else { "new" }
          let cleanup = if remove { "remove" } else { "keep" }
          transfer_scenario_call(
            executor,
            work,
            "curl",
            "empty-output-\{completion}-\{prior}-\{cleanup}",
            [
              "-s",
              "-o",
              "output",
              ..if remove {
                ["--remove-on-error"]
              } else {
                []
              },
              base +
              (if complete {
                "/transfer-empty-complete"
              } else {
                "/transfer-fixed-empty"
              }),
            ],
            "",
            [None],
            requests,
            oracle_failures,
            initial_files=if existing { [("output", "preserve")] } else { [] },
            files=[
              (
                "output",
                if complete {
                  Some("")
                } else if existing {
                  Some("preserve")
                } else {
                  None
                },
              ),
            ],
            oracle_image?,
          )
        }
      }
    }
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "remove-partial",
      [
        "-s",
        "--remove-on-error",
        "-o",
        "partial.bin",
        base + "/transfer-fixed-prefix",
      ],
      "",
      [None],
      requests,
      oracle_failures,
      files=[("partial.bin", None)],
      oracle_image?,
    )
    for remove in [false, true] {
      transfer_scenario_call(
        executor,
        work,
        "curl",
        if remove {
          "remove-named"
        } else {
          "keep-named"
        },
        [
          "-sJO",
          ..if remove {
            ["--remove-on-error"]
          } else {
            []
          },
          base + "/transfer-named-prefix",
        ],
        "",
        [None],
        requests,
        oracle_failures,
        files=[("wire-partial.bin", if remove { None } else { Some("hello") })],
        oracle_image?,
      )
    }
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "default-retry-does-not-retry-partial",
      ["-s", "--retry", "2", base + "/transfer-fixed-prefix"],
      "hello",
      [None],
      requests,
      oracle_failures,
      oracle_image?,
    )
    for file in [false, true] {
      transfer_scenario_call(
        executor,
        work,
        "curl",
        if file {
          "retry-all-file"
        } else {
          "retry-all-stdout"
        },
        [
          "-s",
          "--retry",
          "2",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          ..if file {
            ["-o", "partial.bin"]
          } else {
            []
          },
          base + "/transfer-fixed-prefix",
        ],
        if file {
          ""
        } else {
          "hellohellohello"
        },
        [None, None, None],
        requests,
        oracle_failures,
        files=if file { [("partial.bin", Some("hello"))] } else { [] },
        oracle_image?,
      )
    }
    for mode in ["file-new", "file-existing", "stdout"] {
      let file = mode != "stdout"
      let initial_files = if mode == "file-existing" {
        [("partial.bin", "preserve")]
      } else {
        []
      }
      transfer_scenario_call(
        executor,
        work,
        "curl",
        "retry-partial-empty-" + mode,
        [
          "-sS",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          ..if file {
            ["-o", "partial.bin"]
          } else {
            []
          },
          base + "/transfer-retry-empty",
        ],
        if file {
          ""
        } else {
          "hello"
        },
        [None, None],
        requests,
        oracle_failures,
        initial_files~,
        files=if file { [("partial.bin", Some(""))] } else { [] },
        expected_stderr="curl: (18) end of response with 4 bytes missing\n" +
          "curl: (18) end of response with 9 bytes missing\n",
        methods=["GET", "GET"],
        bodies=[b"", b""],
        transfer_files~,
        expected_files_before_response=[
          initial_files,
          if file {
            [("partial.bin", "")]
          } else {
            []
          },
        ],
        oracle_image?,
      )
    }
    for
      (label, complete, existing) in [
        ("remove-partial-empty-new", false, false),
        ("remove-partial-empty-existing", false, true),
        ("remove-partial-complete-new", true, false),
      ] {
      let initial_files = if existing {
        [("output.bin", "preserve")]
      } else {
        []
      }
      transfer_scenario_call(
        executor,
        work,
        "curl",
        label,
        [
          "-sS",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          "-o",
          "output.bin",
          "--remove-on-error",
          base +
          (if complete {
            "/transfer-retry-complete"
          } else {
            "/transfer-retry-empty"
          }),
        ],
        "",
        [None, None],
        requests,
        oracle_failures,
        initial_files~,
        files=[("output.bin", if complete { Some("ok") } else { None })],
        expected_stderr="curl: (18) end of response with 4 bytes missing\n" +
          (if complete {
            ""
          } else {
            "curl: (18) end of response with 9 bytes missing\n"
          }),
        methods=["GET", "GET"],
        bodies=[b"", b""],
        transfer_files~,
        expected_files_before_response=[initial_files, [("output.bin", "")]],
        oracle_image?,
      )
    }
    for
      (label, endpoint, complete, remove) in [
        ("cd-partial-empty-changed", "empty-changed", false, false),
        ("cd-partial-complete-changed", "complete-changed", true, false),
        ("cd-partial-complete-missing", "complete-missing", true, false),
        ("cd-partial-empty-changed-remove", "empty-changed", false, true),
        ("cd-partial-complete-changed-remove", "complete-changed", true, true),
      ] {
      transfer_scenario_call(
        executor,
        work,
        "curl",
        label,
        [
          "-s",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          "-O",
          "-J",
          ..if remove {
            ["--remove-on-error"]
          } else {
            []
          },
          base + "/transfer-retry-named-" + endpoint,
        ],
        "",
        [None, None],
        requests,
        oracle_failures,
        files=[
          (
            "first.bin",
            if complete {
              Some("ok")
            } else if remove {
              None
            } else {
              Some("")
            },
          ),
          ("second.bin", None),
          ("transfer-retry-named-" + endpoint, None),
        ],
        methods=["GET", "GET"],
        bodies=[b"", b""],
        transfer_files~,
        expected_files_before_response=[[], [("first.bin", "")]],
        oracle_image?,
      )
    }
    for existing in [false, true] {
      let initial_files = if existing {
        [("first.bin", "preserve")]
      } else {
        []
      }
      transfer_scenario_call(
        executor,
        work,
        "curl",
        if existing {
          "cd-first-empty-existing"
        } else {
          "cd-first-empty-new"
        },
        ["-s", "--retry", "0", "-O", "-J", base + "/transfer-named-empty"],
        "",
        [None],
        requests,
        oracle_failures,
        initial_files~,
        files=[
          ("first.bin", Some(if existing { "preserve" } else { "" })),
          ("transfer-named-empty", None),
        ],
        methods=["GET"],
        bodies=[b""],
        transfer_files~,
        expected_files_before_response=[initial_files],
        oracle_image?,
      )
    }
    for status in [200, 304, 404, 500] {
      for completion in ["empty-complete", "empty-incomplete", "body-complete"] {
        for fail_http in [false, true] {
          let endpoint = "transfer-cd-status-\{status}-\{completion}"
          let selected_name = status == 200 || status == 304
          let content = if completion == "body-complete" { "hello" } else { "" }
          transfer_scenario_call(
            executor,
            work,
            "curl",
            "cd-status-\{status}-\{completion}-fail-\{fail_http}",
            [
              "-s",
              "--retry",
              "0",
              "-O",
              "-J",
              ..if fail_http {
                ["--fail"]
              } else {
                []
              },
              base + "/" + endpoint,
            ],
            "",
            [None],
            requests,
            oracle_failures,
            files=[
              (
                "selected.bin",
                if selected_name {
                  Some(if status == 304 { "" } else { content })
                } else {
                  None
                },
              ),
              (
                endpoint,
                if selected_name ||
                  fail_http ||
                  completion == "empty-incomplete" {
                  None
                } else {
                  Some(content)
                },
              ),
            ],
            methods=["GET"],
            bodies=[b""],
            transfer_files~,
            expected_files_before_response=[[]],
            oracle_image?,
          )
        }
      }
    }
    for endpoint in ["retry-range", "retry-ignore", "retry-ignore-changed"] {
      for file in [false, true] {
        transfer_scenario_call(
          executor,
          work,
          "wget",
          endpoint + (if file { "-file" } else { "-stdout" }),
          [
            "-q",
            "-t",
            "2",
            "--waitretry=0.001",
            "-O",
            if file {
              "result.bin"
            } else {
              "-"
            },
            base + "/transfer-" + endpoint,
          ],
          if file {
            ""
          } else {
            "helloworld"
          },
          [None, Some("bytes=5-")],
          requests,
          oracle_failures,
          files=if file { [("result.bin", Some("helloworld"))] } else { [] },
          oracle_image?,
        )
      }
      transfer_scenario_call(
        executor,
        work,
        "wget",
        endpoint + "-aggregate",
        [
          "-q",
          "-t",
          "2",
          "--waitretry=0.001",
          "-O",
          "aggregate.bin",
          base + "/transfer-fixed-complete",
          base + "/transfer-" + endpoint,
        ],
        "",
        [None, None, Some("bytes=5-")],
        requests,
        oracle_failures,
        files=[("aggregate.bin", Some("hellohelloworld"))],
        oracle_image?,
      )
      transfer_scenario_call(
        executor,
        work,
        "wget",
        endpoint + "-default-file",
        ["-q", "-t", "2", "--waitretry=0.001", base + "/transfer-" + endpoint],
        "",
        [None, Some("bytes=5-")],
        requests,
        oracle_failures,
        files=[("transfer-" + endpoint, Some("helloworld"))],
        oracle_image?,
      )
    }
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-unique-keeps-actual-name",
      ["-q", "-t", "2", "--waitretry=0.001", base + "/transfer-retry-range"],
      "",
      [None, Some("bytes=5-")],
      requests,
      oracle_failures,
      initial_files=[("transfer-retry-range", "existing")],
      files=[
        ("transfer-retry-range", Some("existing")),
        ("transfer-retry-range.1", Some("helloworld")),
        ("transfer-retry-range.2", None),
      ],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-content-disposition-keeps-actual-name",
      [
        "-q",
        "-t",
        "2",
        "--waitretry=0.001",
        "--content-disposition",
        base + "/transfer-retry-named",
      ],
      "",
      [None, Some("bytes=5-")],
      requests,
      oracle_failures,
      initial_files=[("wire-retry.bin", "existing")],
      files=[
        ("wire-retry.bin", Some("existing")),
        ("wire-retry.bin.1", Some("helloworld")),
        ("wire-retry.bin.2", None),
        ("transfer-retry-named", None),
      ],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-wrong-range-preserves-prefix",
      [
        "-q",
        "-t",
        "2",
        "--waitretry=0.001",
        "-O",
        "partial.bin",
        base + "/transfer-retry-wrong-range",
      ],
      "",
      [None, Some("bytes=5-")],
      requests,
      oracle_failures,
      files=[("partial.bin", Some("hello"))],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-empty-is-bounded",
      [
        "-q",
        "-t",
        "2",
        "--waitretry=0.001",
        "-O",
        "-",
        base + "/transfer-fixed-empty",
      ],
      "",
      [None, None],
      requests,
      oracle_failures,
      oracle_image?,
    )
    for endpoint in ["resume-name-change", "resume-name-change-ignore"] {
      for existing in [false, true] {
        transfer_scenario_call(
          executor,
          work,
          "wget",
          endpoint + (if existing { "-existing" } else { "-new" }),
          [
            "-q",
            "-t",
            "1",
            "-c",
            "--content-disposition",
            base + "/transfer-" + endpoint,
          ],
          "",
          if endpoint == "resume-name-change" {
            [None]
          } else {
            [None, if existing { Some("bytes=8-") } else { None }]
          },
          requests,
          oracle_failures,
          initial_files=[
            ("transfer-" + endpoint, "abc"),
            ..if existing {
              [("renamed.bin", "preserve")]
            } else {
              []
            },
          ],
          files=[
            ("transfer-" + endpoint, Some("abc")),
            (
              "renamed.bin",
              if existing {
                Some("preserve")
              } else if endpoint == "resume-name-change-ignore" {
                Some("abcdef")
              } else {
                None
              },
            ),
          ],
          methods=if endpoint == "resume-name-change" {
            ["HEAD"]
          } else {
            ["HEAD", "GET"]
          },
          oracle_image?,
        )
      }
    }
    for
      (label, prefix, range) in [
        ("shorter-than-resource", "abc", "bytes=3-"),
        ("equal-resource", "abcdef", "bytes=6-"),
        ("longer-than-resource", "abcdefg", "bytes=7-"),
      ] {
      transfer_scenario_call(
        executor,
        work,
        "wget",
        "resume-unsatisfied-" + label,
        ["-q", "-t", "1", "-c", base + "/transfer-resume-unsatisfied"],
        "",
        [Some(range)],
        requests,
        oracle_failures,
        initial_files=[("transfer-resume-unsatisfied", prefix)],
        files=[("transfer-resume-unsatisfied", Some(prefix))],
        oracle_image?,
      )
    }
    for variant in ["malformed", "missing"] {
      for
        (prefix, range) in [
          ("abc", "bytes=3-"),
          ("abcdef", "bytes=6-"),
          ("abcdefg", "bytes=7-"),
        ] {
        let endpoint = "transfer-resume-unsatisfied-" + variant
        transfer_scenario_call(
          executor,
          work,
          "wget",
          "resume-unsatisfied-\{variant}-local-\{prefix.length()}",
          ["-q", "-t", "1", "-c", base + "/" + endpoint],
          "",
          [Some(range)],
          requests,
          oracle_failures,
          initial_files=[(endpoint, prefix)],
          files=[(endpoint, Some(prefix))],
          oracle_image?,
        )
      }
    }
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "resume-unsatisfied-without-resume",
      ["-q", "-t", "1", base + "/transfer-resume-unsatisfied"],
      "",
      [None],
      requests,
      oracle_failures,
      files=[("transfer-resume-unsatisfied", None)],
      oracle_image?,
    )
    for existing in [false, true] {
      transfer_scenario_call(
        executor,
        work,
        "wget",
        "resume-named-valid-" + (if existing { "existing" } else { "new" }),
        [
          "-q",
          "-t",
          "1",
          "-c",
          "--content-disposition",
          base + "/transfer-resume-named-valid",
        ],
        "",
        [None, if existing { Some("bytes=3-") } else { None }],
        requests,
        oracle_failures,
        initial_files=[
          ("transfer-resume-named-valid", "original"),
          ..if existing {
            [("renamed.bin", "abc")]
          } else {
            []
          },
        ],
        files=[
          ("transfer-resume-named-valid", Some("original")),
          ("renamed.bin", Some("abcdef")),
        ],
        methods=["HEAD", "GET"],
        oracle_image?,
      )
    }
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "resume-nonfinal-range",
      ["-q", "-t", "1", "-c", base + "/transfer-resume-nonfinal-range"],
      "",
      [Some("bytes=3-")],
      requests,
      oracle_failures,
      initial_files=[("transfer-resume-nonfinal-range", "abc")],
      files=[("transfer-resume-nonfinal-range", Some("abcde"))],
      oracle_image?,
    )
    network_wire_scenario(executor, work, oracle_failures, oracle_image?)
    if !oracle_failures.is_empty() {
      fail(oracle_failures.join("; "))
    }
  })
}
