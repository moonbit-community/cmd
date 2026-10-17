///|
async test "network fixture startup failure retains cleanup errors and deadlines" {
  for phase in ["read", "deadline"] {
    let cleaned = Ref(0)
    try {
      let _ : Int32 = await_fixture_startup(
        "HTTP",
        5,
        () => {
          if phase == "read" {
            fail("injected port read failure")
          }
          @async.sleep(60000)
          1234
        },
        () => {
          cleaned.val += 1
          @async.sleep(1)
          fail("injected child wait failure")
        },
      )
    } catch {
      error => {
        let detail = error.to_string()
        assert_true(detail.contains("child wait failure"))
        assert_true(detail.contains("direct child cleanup failed"))
        if phase == "read" {
          assert_true(detail.contains("port read failure"))
        } else {
          assert_true(detail.contains("startup deadline exceeded"))
        }
      }
    } noraise {
      _ => fail("a failed fixture must not return an endpoint")
    }
    assert_eq(cleaned.val, 1)
  }
}

///|
async test "network fixture cancellation waits for cleanup before returning" {
  let cleaned = Ref(false)
  let completed = @async.with_timeout_opt(5, () => {
    await_fixture_startup(
      "HTTPS",
      60000,
      () => {
        @async.sleep(60000)
        "unreachable endpoint"
      },
      () => {
        @async.sleep(10)
        cleaned.val = true
      },
    )
  })
  assert_eq(completed, None)
  assert_true(cleaned.val)
  let cleanup_count = Ref(0)
  let url = await_fixture_startup("HTTP", 1000, () => "http://127.0.0.1:1234", () => {
    cleanup_count.val += 1
  })
  assert_eq(url, "http://127.0.0.1:1234")
  assert_eq(cleanup_count.val, 0)
}

///|
async test "network fixture startup deadline reaps the actual direct child" {
  if host_platform() == "windows" {
    return
  }
  require_lifecycle_observers(["/bin/sleep", "/bin/kill"])
  // Fixed host observers exercise process ownership without implementing a
  // command or implying ownership of arbitrary grandchildren.
  @async.with_task_group(group => {
    let child = @process.spawn(group, "/bin/sleep", ["30"], no_wait=true)
    try {
      let _ : String = await_fixture_startup(
        "HTTP",
        5,
        () => {
          @async.sleep(60000)
          "unreachable endpoint"
        },
        () => {
          child.cancel()
          ignore(child.wait())
        },
      )
    } catch {
      error =>
        assert_true(error.to_string().contains("startup deadline exceeded"))
    } noraise {
      _ => fail("a fixture without a port must reach its deadline")
    }
    assert_true(child.try_wait() is Some(_))
    let observed = run("/bin/kill", ["-0", child.pid.to_string()])
    assert_true(
      observed.status != 0,
      msg="fixture direct child remains after startup cleanup",
    )
  })
}

///|
test "network fixture endpoint rejects invalid and out-of-range ports" {
  for invalid in ["", "not-a-port", "0", "-1", "65536"] {
    try fixture_port("HTTP", invalid) catch {
      error => assert_true(error.to_string().contains("fixture reported"))
    } noraise {
      _ => fail("invalid fixture port must not become an endpoint")
    }
  }
  assert_eq(fixture_port("HTTPS", " 65535 \n"), 65535)
}
