///|
async test "slow output consumes exact binary bytes through backpressure" {
  let root = @fs.tmpdir(prefix="cmd-slow-output-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  @fs.write_file(input, Bytes::makei(262147, i => (i % 251).to_byte()))
  let invocation = transport_observer_invocation(
    transport_copy_observer(),
    root,
    input,
  )
  let observed = measure_invocation_slow_output(
    invocation,
    root + "/out",
    root + "/err",
    15000,
    4093,
    1,
  )
  assert_eq(observed.status, Some(0))
  assert_eq(observed.error, None)
  assert_false(observed.timed_out)
  assert_true(files_equal(input, root + "/out"))
  assert_eq(@fs.file_size(root + "/err"), 0L)
}

///|
async test "slow consumer failure and deadline cannot supply a passing process observation" {
  let root = @fs.tmpdir(prefix="cmd-slow-output-failure-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  prepare_input(input, 8388608)
  let invocation = transport_observer_invocation(
    transport_copy_observer(),
    root,
    input,
  )
  let broken = measure_invocation_slow_output(
    invocation,
    root + "/broken",
    root + "/broken.err",
    15000,
    4093,
    1,
    fail_after=8192L,
  )
  assert_true(
    broken.error is Some(message) &&
    message.contains("injected slow consumer failure"),
  )
  assert_true(broken.status is Some(_))
  assert_true(@fs.file_size(root + "/broken") < 8388608L)
  let deadline = measure_invocation_slow_output(
    invocation,
    root + "/deadline",
    root + "/deadline.err",
    if @async.platform is Windows {
      5000
    } else {
      500
    },
    257,
    20,
  )
  assert_true(deadline.timed_out)
  assert_eq(deadline.error, None)
  assert_true(deadline.status is Some(_))
  assert_true(@fs.file_size(root + "/deadline") < 8388608L)
  @fs.remove(input)
}
