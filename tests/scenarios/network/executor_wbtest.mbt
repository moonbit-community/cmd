///|
async test "shared network executor retains exact identity and incomplete output evidence" {
  let directory = @fs.tmpdir(prefix="mooncmd-shared-network-")
  defer (@fs.rmdir(directory, recursive=true) catch { _ => () })
  for index in 0..<3 {
    let work = directory + "/" + index.to_string()
    @fs.mkdir(work)
    let executor : Executor = {
      proof: None,
      invoke: invocation => {
        assert_eq(invocation.command, "curl")
        assert_eq(invocation.stdin, b"\x00\xff")
        assert_eq(invocation.cwd, work)
        assert_eq(invocation.environment.get("NO_PROXY"), Some("*"))
        {
          run: {
            output: {
              status: 18,
              stdout: b"partial\x00",
              stderr: b"diagnostic\n",
            },
            timed_out: index == 1,
            cleanup_error: if index == 2 {
              Some("child cleanup failed")
            } else {
              None
            },
          },
          source_version: "cli/curl@0.2.3",
          program: "selected-moonx",
          args: ["cli/curl@0.2.3", "--", "--", "operand"],
          infrastructure_error: None,
          retain_identity: true,
        }
      },
    }
    let error = try {
      let result = network_request(
        executor,
        work,
        "curl",
        ["--", "operand"],
        stdin=b"\x00\xff",
      )
      assert_eq(result.status, 18)
      ""
    } catch {
      error => error.to_string()
    }
    assert_eq(error.is_empty(), index == 0)
    if index > 0 {
      assert_true(error.contains("infrastructure"))
    }
    assert_eq(
      @fs.read_file(work + "/call-0.stdout.bin").binary(),
      b"partial\x00",
    )
    assert_eq(
      @fs.read_file(work + "/call-0.stderr.bin").binary(),
      b"diagnostic\n",
    )
    assert_eq(@fs.read_file(work + "/call-0.status.txt").text(), "18")
    let receipt = @fs.read_file(work + "/call-0.execution.json").text()
    assert_true(receipt.contains("cli/curl@0.2.3"))
    assert_true(receipt.contains("selected-moonx"))
    assert_true(
      @fs.read_file(work + "/call-0.request.json")
      .text()
      .contains("cli/curl@0.2.3"),
    )
  }
}

///|
async test "outer cancellation retains invocation intent without fabricating execution" {
  let work = @fs.tmpdir(prefix="mooncmd-network-cancel-")
  defer (@fs.rmdir(work, recursive=true) catch { _ => () })
  let entered = Ref(false)
  let executor : Executor = {
    proof: None,
    invoke: _ => {
      assert_true(@fs.exists(work + "/call-0.intent.json"))
      entered.val = true
      @async.sleep(10000)
      {
        run: {
          output: { status: 0, stdout: b"", stderr: b"", },
          timed_out: false,
          cleanup_error: None,
        },
        source_version: "unreturned",
        program: "unreturned",
        args: [],
        infrastructure_error: None,
        retain_identity: true,
      }
    },
  }
  let finished = @async.with_timeout_opt(500, () => {
    ignore(
      network_request(executor, work, "wget", ["--keep-session-cookies", "url"]),
    )
  })
  assert_true(finished is None)
  assert_true(entered.val)
  assert_false(@fs.exists(work + "/call-0.execution.json"))
  assert_false(@fs.exists(work + "/call-0.status.txt"))
  assert_true(
    @json.parse(@fs.read_file(work + "/call-0.intent.json").text())
    is { "command": "wget", "phase": "before-invoke", .. },
  )
  assert_true(
    @json.parse(@fs.read_file(work + "/call-0.invocation-end.json").text())
    is { "returned": false, .. },
  )
}

///|
async test "invocation intent does not appear among product-created files" {
  let work = @fs.tmpdir(prefix="mooncmd-network-effects-")
  defer (@fs.rmdir(work, recursive=true) catch { _ => () })
  let executor : Executor = {
    proof: None,
    invoke: _ => {
      @fs.write_file(work + "/out.bin", b"body")
      {
        run: {
          output: { status: 0, stdout: b"", stderr: b"", },
          timed_out: false,
          cleanup_error: None,
        },
        source_version: "fixture",
        program: "fixture",
        args: [],
        infrastructure_error: None,
        retain_identity: true,
      }
    },
  }
  ignore(
    network_request(executor, work, "curl", ["url"], expected_files=[
      ("out.bin", Some("body")),
    ]),
  )
  assert_eq(
    @json.parse(@fs.read_file(work + "/call-0.files.json").text()),
    Json(["out.bin"]),
  )
  assert_true(
    @json.parse(@fs.read_file(work + "/call-0.invocation-end.json").text())
    is { "returned": true, .. },
  )
}

///|
async test "before-response snapshots exclude exactly the current invocation intent" {
  let work = @fs.tmpdir(prefix="mooncmd-network-before-response-")
  defer (@fs.rmdir(work, recursive=true) catch { _ => () })
  @fs.write_file(work + "/call-999.intent.json", b"product")
  let observation : TransferFileObservation = {
    work: None,
    evidence_name: None,
    snapshots: [],
  }
  let executor : Executor = {
    proof: None,
    invoke: _ => {
      observation.capture()
      @fs.write_file(work + "/out.bin", b"body")
      observation.capture()
      {
        run: {
          output: { status: 0, stdout: b"", stderr: b"", },
          timed_out: false,
          cleanup_error: None,
        },
        source_version: "fixture",
        program: "fixture",
        args: [],
        infrastructure_error: None,
        retain_identity: true,
      }
    },
  }
  ignore(
    network_request(
      executor,
      work,
      "curl",
      ["url"],
      transfer_files=observation,
      expected_files=[
        ("call-999.intent.json", Some("product")),
        ("out.bin", Some("body")),
      ],
      expected_files_before_response=[
        [("call-999.intent.json", "product")],
        [("call-999.intent.json", "product"), ("out.bin", "body")],
      ],
    ),
  )
  assert_eq(observation.snapshots.length(), 2)
  assert_eq(observation.work, None)
  assert_eq(observation.evidence_name, None)
}

///|
async test "shared network observations preserve raw bytes across launch adapters" {
  let work = @fs.tmpdir(prefix="mooncmd-network-adapter-")
  defer (@fs.rmdir(work, recursive=true) catch { _ => () })
  let executor : Executor = {
    proof: None,
    invoke: _ => {
      run: {
        output: { status: 0, stdout: b"ok", stderr: b"", },
        timed_out: false,
        cleanup_error: None,
      },
      source_version: "/actual/build/curl.wasm",
      program: "moonrun",
      args: ["/actual/build/curl.wasm", "--", "url"],
      infrastructure_error: None,
      retain_identity: false,
    },
  }
  ignore(network_request(executor, work, "curl", ["url"]))
  assert_false(@fs.exists(work + "/call-0.execution.json"))
  assert_eq(
    @fs.read_file(work + "/call-0.request.json").text(),
    ({ "command": Json("curl"), "args": Json(["url"]) } : Json).stringify(
      indent=2,
    ),
  )
}
