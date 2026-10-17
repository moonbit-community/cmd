///|
async fn lifecycle_oracle_profile(root : String) -> (String, OracleProfile) {
  let recipe = "lifecycle fixture recipe\n"
  let inventory_recipe = "lifecycle fixture inventory recipe\n"
  let versions = "fixture-oracle 1.0\n"
  @fs.write_file(root + "/Dockerfile", recipe)
  @fs.write_file(root + "/versions.sh", inventory_recipe)
  let profile : OracleProfile = {
    schema: 1,
    id: "lifecycle-oracle",
    profile_version: 1,
    image: "lifecycle-oracle:fixture",
    base_image_digest: "sha256:" + sha256_text("base fixture"),
    image_digest: "sha256:" + sha256_text("image fixture"),
    versions,
    versions_sha256: sha256_text(versions),
    dockerfile_sha256: sha256_text(recipe),
    versions_script_sha256: sha256_text(inventory_recipe),
    sources: [
      {
        project: "fixture-oracle",
        version: "1.0",
        sha256: sha256_text("source fixture"),
      },
    ],
  }
  let path = root + "/profile.json"
  @fs.write_file(path, canonical_json(ToJson::to_json(profile)))
  (path, profile)
}

///|
async test "missing Docker is an oracle infrastructure failure" {
  let root = @fs.tmpdir(prefix="mooncmd-oracle-missing-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let (profile_path, profile) = lifecycle_oracle_profile(root)
  try
    verify_oracle_image(
      profile.image,
      docker_path=root + "/missing-docker",
      profile_path~,
    )
  catch {
    error =>
      assert_true(
        error.to_string().contains("oracle image inspect unavailable"),
      )
  } noraise {
    _ => fail("a missing Docker executable must reject oracle verification")
  }
  assert_true(@fs.exists(profile_path))
}

///|
async test "oracle digest mismatch stops before inventory execution" {
  let root = @fs.tmpdir(prefix="mooncmd-oracle-digest-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let (profile_path, profile) = lifecycle_oracle_profile(root)
  let calls : Array[Array[String]] = []
  try
    verify_oracle_image_with(profile.image, profile_path, args => {
      calls.push(args.copy())
      {
        status: 0,
        stdout: @utf8.encode("sha256:" + sha256_text("wrong image") + "\n"),
        stderr: b"",
      }
    })
  catch {
    error =>
      assert_true(error.to_string().contains("oracle image digest mismatch"))
  } noraise {
    _ => fail("a mismatched image must reject oracle verification")
  }
  assert_eq(calls.length(), 1)
  assert_eq(calls[0], ["image", "inspect", "--format={{.Id}}", profile.image])
}

///|
async test "oracle version mismatch retains immutable inventory selection" {
  let root = @fs.tmpdir(prefix="mooncmd-oracle-version-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let (profile_path, profile) = lifecycle_oracle_profile(root)
  let calls : Array[Array[String]] = []
  try
    verify_oracle_image_with(profile.image, profile_path, args => {
      calls.push(args.copy())
      {
        status: 0,
        stdout: @utf8.encode(
          if args[0] == "image" {
            profile.image_digest + "\n"
          } else {
            "changed inventory\n"
          },
        ),
        stderr: b"",
      }
    })
  catch {
    error =>
      assert_true(
        error.to_string().contains("oracle version inventory mismatch"),
      )
  } noraise {
    _ => fail("a changed version inventory must reject oracle verification")
  }
  assert_eq(calls.length(), 2)
  assert_eq(calls[1], [
    "run",
    "--rm",
    profile.image_digest,
    "/usr/local/bin/versions.sh",
  ])
}

///|
async test "oracle inventory failure is never an accepted identity" {
  let root = @fs.tmpdir(prefix="mooncmd-oracle-inventory-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let (profile_path, profile) = lifecycle_oracle_profile(root)
  try
    verify_oracle_image_with(profile.image, profile_path, args => {
      if args[0] == "image" {
        {
          status: 0,
          stdout: @utf8.encode(profile.image_digest + "\n"),
          stderr: b"",
        }
      } else {
        {
          status: 27,
          stdout: b"partial inventory",
          stderr: b"inventory observer failed",
        }
      }
    })
  catch {
    error =>
      assert_true(
        error
        .to_string()
        .contains("oracle inventory failed: inventory observer failed"),
      )
  } noraise {
    _ => fail("a failed inventory observer must not produce an identity")
  }
}

///|
async test "missing metadata observer never produces a partial snapshot" {
  if host_platform() == "windows" {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-observer-missing-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/preserved", b"original bytes")
  try snapshot(root, observe=["mode"], stat_path=root + "/missing-stat") catch {
    error =>
      assert_true(
        error.to_string().contains("required observation unavailable: mode"),
      )
  } noraise {
    _ => fail("unavailable metadata must not produce a successful snapshot")
  }
  assert_eq(@fs.read_file(root + "/preserved").binary(), b"original bytes")
}

///|
async test "snapshot failure after success retains streams and infrastructure classification" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/rm"])
  let root = @fs.tmpdir(prefix="mooncmd-snapshot-failure-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/cli/remove-fixture", recursive=true)
  // This host observer destroys its own fixture to exercise the harness's
  // snapshot failure path; it is not a command package implementation.
  @fs.symlink(root + "/cli/remove-fixture/remove-fixture.exe", target="/bin/rm")
  let fixture : Case = @json.from_json({
    "id": "snapshot-failure",
    "command": "remove-fixture",
    "args": ["-rf", "${WORK}"],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
  })
  let report = execute_contract(
    fixture,
    root,
    false,
    root + "/reports",
    retain_success=true,
  )
  assert_eq(report.result, "infra", msg=report.detail)
  assert_eq(report.stage, "snapshot")
  assert_eq(report.observations, [])
  guard report.evidence is Some(evidence) else {
    fail("snapshot failure must retain evidence")
  }
  assert_eq(@fs.read_file(evidence + "/status.txt").text(), "0")
  assert_eq(@fs.read_file(evidence + "/stdout.bin").binary(), b"")
  assert_eq(@fs.read_file(evidence + "/stderr.bin").binary(), b"")
}

///|
async test "deadline returns only after the direct child is reaped" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/sh", "/bin/kill"])
  // The fixed host observer prints its PID and then becomes the same direct
  // child through exec. Signal zero also detects unreaped POSIX zombies.
  let result = run_with_deadline(
    "/bin/sh",
    ["-c", "printf '%s\n' \"$$\"; exec sleep 30"],
    500,
  )
  assert_true(result.timed_out)
  assert_eq(result.cleanup_error, None)
  assert_true(result.output.status != -1)
  let pid = @utf8.decode(result.output.stdout).trim().to_owned()
  assert_true(@string.parse_int(pid) > 1)
  let observed = run("/bin/kill", ["-0", pid])
  assert_true(
    observed.status != 0,
    msg="direct child still exists after deadline cleanup",
  )
}

///|
async test "cleanup permission failure retains candidate evidence" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/chmod", "/usr/bin/id"])
  let identity = run("/usr/bin/id", ["-u"])
  require_lifecycle_unprivileged_user(identity)
  let root = @fs.tmpdir(prefix="mooncmd-cleanup-failure-")
  let evidence = root + "/reports/cleanup-failure"
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  // Restore access even when the regression fails, so a test fault cannot
  // leave deliberately protected directories in the caller's temp root.
  defer (ignore(run("/bin/chmod", ["700", evidence])) catch { _ => () })
  @fs.mkdir(root + "/cli/protect-evidence", recursive=true)
  @fs.symlink(
    root + "/cli/protect-evidence/protect-evidence.exe",
    target="/bin/chmod",
  )
  let fixture : Case = @json.from_json({
    "id": "cleanup-failure",
    "command": "protect-evidence",
    "args": ["500", "${WORK}/.."],
    "files": [],
    "environment": {},
    "expected_status": 0,
    "comparison": "contract",
    "expected_stdout_text": "",
    "expected_stderr_text": "",
    "normalizations": [],
  })
  let report = execute_contract(fixture, root, false, root + "/reports")
  assert_eq(report.result, "infra", msg=report.detail)
  assert_eq(report.stage, "cleanup")
  assert_eq(report.evidence, Some(evidence + ".cleanup-evidence"))
  assert_true(@fs.exists(evidence + "/work"))
  assert_eq(report.observations, [])
  assert_eq(
    @fs.read_file(evidence + ".cleanup-evidence/status.txt").text(),
    "0",
  )
  assert_eq(
    @fs.read_file(evidence + ".cleanup-evidence/stdout.bin").binary(),
    b"",
  )
  assert_eq(
    @fs.read_file(evidence + ".cleanup-evidence/stderr.bin").binary(),
    b"",
  )
  assert_eq(
    @fs.read_file(evidence + ".cleanup-evidence/fixture-path.txt").text(),
    evidence + "\n",
  )
}

///|
fn lifecycle_listener_owners(
  result : RunResult,
  windows : Bool,
) -> Array[Int32] raise {
  let output = @utf8.decode(result.stdout).trim().to_owned()
  guard result.stderr == b"" &&
    (result.status == 0 || (!windows && result.status == 1 && output == "")) else {
    fail(
      "listener observer infrastructure failure: status=\{result.status}, stderr=\{@utf8.decode(result.stderr)}",
    )
  }
  if output == "" {
    guard windows || result.status == 1 else {
      fail(
        "listener observer infrastructure failure: empty successful lsof output",
      )
    }
    return []
  }
  let owners : Array[Int32] = []
  for line in output.split("\n") {
    let pid = line.trim().to_owned()
    guard pid != "" && pid.iter().all(char => char is ('0'..<='9')) else {
      fail("listener observer infrastructure failure: invalid owner PID")
    }
    let pid = @string.parse_int(pid) catch {
      _ => fail("listener observer infrastructure failure: invalid owner PID")
    }
    guard pid > 0 else {
      fail("listener observer infrastructure failure: nonpositive owner PID")
    }
    owners.push(pid)
  }
  owners
}

///|
async fn observe_lifecycle_listener(port : Int32) -> Array[Int32] {
  let windows = host_platform() == "windows"
  let program = if windows {
    "powershell.exe"
  } else if host_platform() == "macos" {
    "/usr/sbin/lsof"
  } else {
    "/usr/bin/lsof"
  }
  let args = if windows {
    [
      "-NoLogo",
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'; Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.State -eq 'Listen' -and $_.LocalAddress -eq '127.0.0.1' -and $_.LocalPort -eq \{port} } | ForEach-Object { $_.OwningProcess.ToString() }",
    ]
  } else {
    ["-nP", "-a", "-iTCP@127.0.0.1:\{port}", "-sTCP:LISTEN", "-t"]
  }
  let observed = run_with_deadline(program, args, 15000) catch {
    error => fail("listener observer infrastructure unavailable: \{error}")
  }
  guard !observed.timed_out && observed.cleanup_error is None else {
    fail("listener observer infrastructure did not complete cleanup")
  }
  lifecycle_listener_owners(observed.output, windows)
}

///|
test "listener observation rejects unavailable and malformed diagnostics" {
  assert_eq(
    lifecycle_listener_owners(
      { status: 0, stdout: b"123\n", stderr: b"", },
      false,
    ),
    [123],
  )
  assert_eq(
    lifecycle_listener_owners({ status: 1, stdout: b"", stderr: b"", }, false),
    [],
  )
  assert_eq(
    lifecycle_listener_owners(
      { status: 0, stdout: b"123\r\n", stderr: b"", },
      true,
    ),
    [123],
  )
  assert_eq(
    lifecycle_listener_owners({ status: 0, stdout: b"", stderr: b"", }, true),
    [],
  )
  for
    (result, windows) in [
      ({ status: 0, stdout: b"", stderr: b"", }, false),
      ({ status: 1, stdout: b"123\n", stderr: b"", }, false),
      ({ status: 1, stdout: b"", stderr: b"", }, true),
      ({ status: 0, stdout: b"warning\n", stderr: b"", }, false),
      ({ status: 0, stdout: b"0\n", stderr: b"", }, true),
      ({ status: 0, stdout: b"123\n", stderr: b"unavailable", }, false),
      ({ status: 0, stdout: b"p123\nf32\n", stderr: b"", }, false),
    ] {
    try ignore(lifecycle_listener_owners(result, windows)) catch {
      error => assert_true(error.to_string().contains("infrastructure"))
    } noraise {
      _ => fail("invalid listener diagnostics must not prove closure")
    }
  }
}

///|
async test "HTTP fixture serves requests and releases its listening port" {
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:0")) catch {
    error => fail("HTTP lifecycle fixture could not start: \{error}")
  }
  // This fallback runs after the closure assertion; successful cleanup must
  // come from the owning group after its connection handlers have joined.
  defer server.close()
  // Establish that this observer sees the fixture's actual LISTEN owner.
  // Missing tools or malformed observations are failed prerequisites.
  assert_false(
    observe_lifecycle_listener(server.addr.port()).is_empty(),
    msg="listener observer infrastructure cannot see the active fixture",
  )
  @async.with_timeout(5000, () => {
    @async.with_task_group <| group => {
      // Match the owner-scoped cleanup used by the network, compatibility
      // and policy scenarios. A child-local defer alone is not this contract.
      group.add_defer(() => server.close())
      group.spawn_bg(no_wait=true, () => run_http_fixture(server))
      let (response, body) = @http.get(
        "http://127.0.0.1:\{server.addr.port()}/fixed",
      )
      assert_eq(response.code, 200)
      assert_eq(body.binary(), b"hello")
    }
  })
  // Inspect LISTEN ownership directly. A client connection to a recently
  // freed ephemeral port can self-connect; TIME_WAIT also is not a listener.
  assert_eq(
    observe_lifecycle_listener(server.addr.port()),
    [],
    msg="HTTP fixture retains a LISTEN owner after joined task cleanup",
  )
}

///|
async test "HTTPS fixture rejects untrusted TLS and releases its subprocess port" {
  // The registry excludes Windows until its OpenSSL observer is provisioned
  // and this subprocess/TLS lifecycle has been validated there.
  if host_platform() == "windows" {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-https-lifecycle-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let mut workspace = @fs.realpath(".")
  while !@fs.exists(workspace + "/moon.work") {
    let parent = @path.Path(workspace).dirname().to_string()
    guard parent != workspace else { fail("workspace fixture root not found") }
    workspace = parent
  }
  let port = Ref(0)
  @async.with_task_group <| group => {
    let (child, url) = spawn_https_fixture_process(
      group,
      root,
      fixture_directory=workspace + "/tests/fixtures/http",
    )
    group.add_defer(() => {
      child.cancel()
      @async.protect_from_cancel(() => ignore(child.wait()))
    })
    port.val = @string.parse_int(
      url.strip_prefix("https://127.0.0.1:").unwrap().to_owned(),
    )
    @async.with_timeout(5000, () => {
      // Prove that the fixture can complete TLS and serve its expected bytes
      // before attributing the next request's failure to certificate trust.
      let client = @http.Client(url, trust=@tls.NoVerification)
      defer client.close()
      let response = client.get("/fixed.txt")
      assert_eq(response.code, 200)
      assert_eq(client.read_all().binary(), b"hello\n")
      client.close()
      try @http.get(url + "/fixed.txt") catch {
        @tls.TlsError(_) => ()
        error => fail("expected TLS verification failure, observed \{error}")
      } noraise {
        _ => fail("self-signed fixture must not pass system-root verification")
      }
    })
  }
  let replacement = @socket.TcpServer(
    @socket.Addr::parse("127.0.0.1:\{port.val}"),
    reuse_addr=true,
  )
  replacement.close()
}
