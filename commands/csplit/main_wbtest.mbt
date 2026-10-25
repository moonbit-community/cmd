///|
async fn with_snapshot(
  bytes : Bytes,
  accept : async (Snapshot) -> Unit,
) -> Unit {
  let directory = @fs.tmpdir(prefix="csplit-test-")
  defer @fs.rmdir(directory, recursive=true)
  let data = @fs.open(
    directory + "/input",
    mode=ReadWrite,
    create_mode=CreateNew,
  )
  defer data.close()
  let index = @fs.open(
    directory + "/index",
    mode=ReadWrite,
    create_mode=CreateNew,
  )
  defer index.close()
  let reader = @io.MemoryReader(writer => writer.write(bytes))
  defer reader.close()
  accept(snapshot(reader, data, index))
}

///|
async test "csplit indexes byte lines without a phantom terminal line" {
  with_snapshot(b"a\nb\n", async fn(input) {
    assert_eq(input.records, 2L)
    assert_eq(input.offset(0), 0L)
    assert_eq(input.offset(1), 2L)
    assert_eq(input.offset(2), 4L)
  })
  with_snapshot(b"a\nb", async fn(input) {
    assert_eq(input.records, 2L)
    assert_eq(input.offset(2), 3L)
  })
  with_snapshot(b"", async fn(input) {
    assert_eq(input.records, 0L)
    assert_eq(input.offset(0), 0L)
  })
  with_snapshot(b"a\x00\xff\n", async fn(input) {
    assert_true(input.matches(0, @bytere.compile("^a..$")))
  })
}

///|
async test "csplit pages indexes and regex records across block boundaries" {
  let bytes = Bytes::make(131073, b'\n')
  with_snapshot(bytes, async fn(input) {
    assert_eq(input.records, 131073L)
    assert_eq(input.offset(8191), 8191L)
    assert_eq(input.offset(8192), 8192L)
    assert_eq(input.offset(131073), 131073L)
    assert_eq(input.offset(1), 1L)
    assert_true(input.matches(65535, @bytere.compile("^$")))
  })
  let long = Bytes::make(131073, b'x')
  with_snapshot(long, async fn(input) {
    assert_eq(input.records, 1L)
    assert_true(input.matches(0, @bytere.compile("^x*$")))
  })
}

///|
async fn csplit_fixture(
  input : Bytes,
  patterns : Array[String],
  suppress~ : Bool = false,
) -> Array[Bytes] {
  let directory = @fs.tmpdir(prefix="csplit-partition-test-")
  defer @fs.rmdir(directory, recursive=true)
  let output : Output = {
    prefix: directory + "/part-",
    width: 2,
    suffix: None,
    quiet: true,
    elide: false,
    paths: [],
  }
  let reader = @io.MemoryReader(writer => writer.write(input))
  defer reader.close()
  process(reader, parse_controls(patterns), output, suppress)
  let pieces : Array[Bytes] = []
  for path in output.paths {
    pieces.push(@fs.read_file(path).binary())
  }
  pieces
}

///|
async test "csplit spool retains negative-offset repeat and suppression cursors" {
  let bytes = b"a\nb\nmark\nc\nmark\nd"
  assert_eq(csplit_fixture(bytes, ["/mark/-1", "{*}"]), [
    b"a\n", b"b\nmark\n", b"c\nmark\nd",
  ])
  assert_eq(csplit_fixture(bytes, ["/mark/-1", "{*}"], suppress=true), [
    b"a\n", b"mark\n", b"mark\nd",
  ])
  assert_eq(csplit_fixture(bytes, ["2", "{1}"]), [
    b"a\n", b"b\nmark\n", b"c\nmark\nd",
  ])
}

///|
async test "csplit input failure and observed cancellation create no fragments" {
  let directory = @fs.tmpdir(prefix="csplit-input-failure-test-")
  defer @fs.rmdir(directory, recursive=true)
  let output : Output = {
    prefix: directory + "/part-",
    width: 2,
    suffix: None,
    quiet: true,
    elide: false,
    paths: [],
  }
  let controls = parse_controls(["2"])
  let spool = directory + "/spool"
  @fs.mkdir(spool)
  let failed = @io.MemoryReader(async fn(writer) {
    while !@fs.exists(spool + "/index") {
      @async.sleep(1)
    }
    writer.write(b"first\n")
    fail("injected input failure")
  })
  defer failed.close()
  let rejected = try {
    process_spool(spool, failed, controls, output, false)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_true(!@fs.exists(spool))
  assert_eq(output.paths.length(), 0)
  assert_eq(@fs.readdir(directory), [])
  @fs.mkdir(spool)
  let pending = @io.MemoryReader(async fn(writer) {
    writer.write(b"first\n")
    @async.sleep(10000)
  })
  defer pending.close()
  @async.with_task_group() <| group => {
    let task = group.spawn(() => {
      process_spool(spool, pending, controls, output, false)
    })
    @async.with_timeout(1000, () => {
      while !@fs.exists(spool + "/index") ||
            @fs.file_size(spool + "/input") == 0L {
        @async.sleep(1)
      }
    })
    task.cancel()
    let canceled = try {
      task.wait()
      false
    } catch {
      @async.WaitedTaskAlreadyCancelled => true
      error => raise error
    }
    assert_true(canceled)
  }
  assert_true(!@fs.exists(spool))
  assert_eq(output.paths.length(), 0)
  assert_eq(@fs.readdir(directory), [])
}

///|
test "csplit parses BRE and repeats before any output files are created" {
  let controls = parse_controls(["2", "{3}", "/^item/+1"])
  assert_eq(controls.length(), 2)
  assert_eq(controls[0].repeats, Some(3))
  assert_true(controls[1].pattern is Expression(_, 1, false))
  let plus = parse_pattern("/a\\+b/")
  guard plus is Expression(pattern, 0, false) else {
    fail("expected expression")
  }
  assert_true(pattern.find_span("aaab") is Some(_))
  let literal = parse_pattern("/a+b/")
  guard literal is Expression(pattern, 0, false) else {
    fail("expected expression")
  }
  assert_true(pattern.find_span("a+b") is Some(_))
  let repeated = parse_pattern("/\\(a\\)\\1/")
  guard repeated is Expression(pattern, 0, false) else {
    fail("expected expression")
  }
  assert_eq(pattern.find_span("zaab"), Some((1, 3)))
}

///|
test "csplit suffix integers distinguish precision alternate prefix and width" {
  assert_eq(suffix_format("pre%%-%03d.out").render(0), "pre%-000.out")
  assert_eq(suffix_format("%#04x").render(1), "0x01")
  assert_eq(suffix_format("%.0d").render(0), "")
  assert_eq(suffix_format("%#.0o").render(0), "0")
  assert_eq(suffix_format("%-3d").render(1), "1  ")
}
