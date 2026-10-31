///|
// Fixed host programs observe harness IO and direct-child ownership. They do
// not provide an implementation of any command under test.
fn transport_copy_observer() -> (String, Array[String]) {
  if @async.platform is Windows {
    (
      "powershell.exe",
      [
        "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; [Console]::OpenStandardInput().CopyTo([Console]::OpenStandardOutput())",
      ],
    )
  } else {
    ("/bin/cat", [])
  }
}

///|
fn transport_wait_observer() -> (String, Array[String]) {
  if @async.platform is Windows {
    (
      "powershell.exe",
      [
        "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "[Console]::WriteLine($PID); Start-Sleep -Seconds 30",
      ],
    )
  } else {
    ("/bin/sh", ["-c", "printf '%s\\n' \"$$\"; exec sleep 30"])
  }
}

///|
fn transport_early_observer() -> (String, Array[String]) {
  if @async.platform is Windows {
    (
      "powershell.exe",
      [
        "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; $inputStream = [Console]::OpenStandardInput(); $value = $inputStream.ReadByte(); if ($value -lt 0) { exit 9 }; $outputStream = [Console]::OpenStandardOutput(); $outputStream.WriteByte([byte]$value); $outputStream.Flush(); exit 0",
      ],
    )
  } else {
    ("/usr/bin/head", ["-c", "1"])
  }
}

///|
fn transport_observer_invocation(
  observer : (String, Array[String]),
  directory : String,
  source : String,
) -> BenchmarkInvocation {
  {
    program: observer.0,
    args: observer.1,
    cwd: directory,
    environment: Map([]),
    stdin_path: source,
  }
}

///|
async fn assert_transport_child_reaped(stdout : String) -> Unit {
  let pid = @fs.read_file(stdout).text().trim().to_owned()
  assert_true(@string.parse_int(pid) > 1, msg="observer PID missing")
  let observed = if @async.platform is Windows {
    @testkit.run("powershell.exe", [
      "-NoLogo",
      "-NoProfile",
      "-NonInteractive",
      "-Command",
      "$p = Get-Process -Id \{pid} -ErrorAction SilentlyContinue; if ($null -eq $p) { exit 1 } else { exit 0 }",
    ])
  } else {
    @testkit.run("/bin/kill", ["-0", pid])
  }
  assert_true(
    observed.status != 0,
    msg="direct child still exists after pipe cleanup",
  )
}

///|
async test "pipe transport preserves exact binary bytes across producer fragmentation and EOF" {
  let root = @fs.tmpdir(prefix="cmd-pipe-fragmentation-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  let expected = Bytes::makei(196867, index => (index % 251).to_byte())
  @fs.write_file(input, expected)
  let invocation = transport_observer_invocation(
    transport_copy_observer(),
    root,
    input,
  )
  let regular = measure_invocation(
    invocation,
    root + "/regular",
    root + "/regular.err",
    15000,
  )
  assert_eq(regular.status, Some(0))
  assert_eq(regular.error, None)
  assert_false(regular.timed_out)
  assert_eq(@fs.read_file(root + "/regular").binary(), expected)
  for chunk_bytes in [257, 65537] {
    let output = root + "/pipe-\{chunk_bytes}"
    let observed = measure_invocation_pipe(
      invocation,
      output,
      output + ".err",
      15000,
      chunk_bytes,
    )
    assert_eq(observed.status, Some(0))
    assert_eq(observed.error, None)
    assert_false(observed.timed_out)
    assert_true(finite_positive(observed.elapsed_us))
    assert_true(files_equal(input, output))
    assert_true(files_equal(root + "/regular", output))
    assert_eq(@fs.read_file(output + ".err").binary(), b"")
  }
  @fs.write_file(input, b"")
  let empty = measure_invocation_pipe(
    invocation,
    root + "/empty",
    root + "/empty.err",
    15000,
    257,
  )
  assert_eq(empty.status, Some(0))
  assert_eq(empty.error, None)
  assert_false(empty.timed_out)
  assert_eq(@fs.read_file(root + "/empty").binary(), b"")
}

///|
test "early pipe closure recognizes only typed platform write errors" {
  let code = if @async.platform is Windows { 109 } else { 32 }
  assert_true(
    pipe_writer_closed(
      @os_error.OSError(code, context="@process.WriteToProcess::write()"),
    ),
  )
  assert_false(
    pipe_writer_closed(@os_error.OSError(code, context="source.read()")),
  )
  assert_false(
    pipe_writer_closed(
      @os_error.OSError(13, context="@process.WriteToProcess::write()"),
    ),
  )
  assert_false(
    pipe_writer_closed(
      Failure::Failure("@process.WriteToProcess::write(): Broken pipe (32)"),
    ),
  )
  if @async.platform is Windows {
    assert_true(
      pipe_writer_closed(
        @os_error.OSError(232, context="@process.WriteToProcess::write()"),
      ),
    )
    assert_false(
      pipe_writer_closed(
        @os_error.OSError(32, context="@process.WriteToProcess::write()"),
      ),
    )
  } else {
    for windows_code in [109, 232] {
      assert_false(
        pipe_writer_closed(
          @os_error.OSError(
            windows_code,
            context="@process.WriteToProcess::write()",
          ),
        ),
      )
    }
  }
}

///|
async test "successful early pipe consumer requires explicit permission" {
  let root = @fs.tmpdir(prefix="cmd-pipe-early-close-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  @fs.write_file(input, Bytes::make(4194304, b'x'))
  let invocation = transport_observer_invocation(
    transport_early_observer(),
    root,
    input,
  )
  for allow_early_close in [false, true] {
    let output = root + "/stdout-" + allow_early_close.to_string()
    let observed = measure_invocation_pipe(
      invocation,
      output,
      output + ".err",
      30000,
      65537,
      allow_early_close~,
    )
    assert_eq(observed.status, Some(0))
    assert_false(observed.timed_out)
    assert_true(finite_positive(observed.elapsed_us))
    assert_eq(@fs.read_file(output).binary(), b"x")
    assert_eq(@fs.read_file(output + ".err").binary(), b"")
    if allow_early_close {
      assert_eq(observed.error, None)
    } else {
      assert_true(
        observed.error is Some(message) &&
        message.contains("pipe producer write failed:"),
      )
    }
  }
}

///|
async test "pipe source failure remains fatal with early closure allowed and reaps the child" {
  let root = @fs.tmpdir(prefix="cmd-pipe-source-failure-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  @fs.write_file(input, Bytes::make(131073, b'x'))
  let stdout = root + "/stdout"
  let calls = Ref(0)
  let observed = measure_invocation_pipe_with_source(
    transport_observer_invocation(transport_wait_observer(), root, input),
    stdout,
    root + "/stderr",
    15000,
    257,
    allow_early_close=true,
    read_chunk=(source, offset, length) => {
      calls.val += 1
      if calls.val == 3 {
        let mut waited = 0
        while !@fs.read_file(stdout).text().contains("\n") && waited < 1000 {
          @async.sleep(10)
          waited += 1
        }
        fail("injected pipe source read failure")
      }
      source.read_exactly_at(length, position=offset)
    },
  )
  assert_eq(calls.val, 3)
  assert_true(
    observed.error is Some(message) &&
    message.contains("injected pipe source read failure"),
  )
  assert_false(observed.timed_out)
  assert_true(observed.status is Some(_))
  assert_transport_child_reaped(stdout)
  // Removing the source also checks that cancellation released its file handle
  // before returning, including on Windows.
  @fs.remove(input)
}

///|
async test "pipe deadline cancels a backpressured producer and reaps its direct child" {
  let root = @fs.tmpdir(prefix="cmd-pipe-timeout-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  prepare_input(input, 8388608)
  let read_bytes = Ref(0L)
  let stdout = root + "/stdout"
  let observed = measure_invocation_pipe_with_source(
    transport_observer_invocation(transport_wait_observer(), root, input),
    stdout,
    root + "/stderr",
    if @async.platform is Windows {
      5000
    } else {
      1000
    },
    65537,
    read_chunk=(source, offset, length) => {
      read_bytes.val += length.to_int64()
      source.read_exactly_at(length, position=offset)
    },
  )
  assert_true(observed.timed_out)
  assert_eq(observed.error, None)
  assert_true(observed.status is Some(_))
  assert_true(read_bytes.val > 0L)
  assert_true(
    read_bytes.val < 8388608L,
    msg="a blocked pipe must not preload the whole source",
  )
  assert_transport_child_reaped(stdout)
  @fs.remove(input)
}
