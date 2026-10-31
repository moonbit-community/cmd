///|
async test "spool cleanup runs once and preserves primary error precedence" {
  for operation_fails in [false, true] {
    for cleanup_fails in [false, true] {
      let events : Array[String] = []
      let error = try {
        with_spool_cleanup(
          () => {
            events.push("operation")
            if operation_fails {
              fail("primary failure")
            }
          },
          () => {
            events.push("cleanup")
            if cleanup_fails {
              fail("cleanup failure")
            }
          },
        )
        None
      } catch {
        error => Some(error.to_string())
      }
      assert_eq(events, ["operation", "cleanup"])
      match error {
        Some(message) =>
          assert_true(
            message.contains(
              if operation_fails {
                "primary failure"
              } else {
                "cleanup failure"
              },
            ),
          )
        None => assert_true(!operation_fails && !cleanup_fails)
      }
    }
  }
}

///|
async test "cancelled spool operations still clean up once" {
  let events : Array[String] = []
  let directory = @tempio.Directory::new(prefix="cli-tac-cancel-")
  let path = directory.path()
  let result = @async.with_timeout_opt(20, () => {
    with_spool_cleanup(
      () => {
        events.push("operation")
        @async.sleep(10000)
      },
      () => {
        directory.close()
        events.push("cleanup")
      },
    )
  })
  assert_true(result is None)
  assert_eq(events, ["operation", "cleanup"])
  assert_false(@fs.exists(path))
}
