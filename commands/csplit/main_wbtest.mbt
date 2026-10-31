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
async test "csplit flushes full index pages before an unterminated final boundary" {
  for lines in [8190, 8191, 8192, 16383] {
    let bytes = Bytes::make(lines, b'\n') + b"tail"
    with_snapshot(bytes, async fn(input) {
      assert_eq(input.records, lines.to_int64() + 1)
      assert_eq(input.offset(0), 0L)
      assert_eq(input.offset(lines.to_int64()), lines.to_int64())
      assert_eq(input.offset(lines.to_int64() + 1), bytes.length().to_int64())
      assert_true(input.matches(lines.to_int64(), @bytere.compile("^tail$")))
    })
  }
}

///|
priv struct FailedIndexWriter {
  mut calls : Int32
}

///|
test "csplit synchronous index scans resume before an uncommitted boundary" {
  let page : IndexPage = {
    bytes: FixedArray::make(16, b'\x00'),
    used: 0,
    entries: 0L,
  }
  let data = b"a\n\xff\x00\n\nlast"
  let base = 0x0123456789abcd00L
  assert_eq(page.scan(data[:], base, 0, base - 3), (5, base + 5))
  assert_eq(page.entries, 2L)
  assert_eq(page.used, 16)
  assert_eq(page.scan(data[:], base, 5, base + 5), (5, base + 5))
  assert_eq(page.entries, 2L)
  try page.push(base) catch {
    error => assert_true(error.to_string().contains("no complete offset slot"))
  } noraise {
    _ => fail("full page must reject before writing")
  }
  assert_eq(page.used, 16)
  assert_eq(page.entries, 2L)
  page.used = 0
  assert_eq(page.scan(data[:], base, 5, base + 5), (10, base + 6))
  assert_eq(page.entries, 3L)
  assert_eq(page.scan(b"tail"[:], base + 10, 0, base + 6), (4, base + 6))
  assert_eq(page.entries, 3L)
}

///|
impl @io.Writer for FailedIndexWriter with fn write_once(self, _, offset~, len~) {
  ignore((offset, len))
  self.calls += 1
  fail("injected index write failure")
}

///|
async test "csplit index pages retain 64 bit offsets and never replay a failed flush" {
  let page : IndexPage = {
    bytes: FixedArray::make(65536, b'\x00'),
    used: 0,
    entries: 0L,
  }
  page.push(0x0123456789abcdefL)
  assert_eq(
    page.bytes.unsafe_reinterpret_as_bytes()[:8],
    b"\xef\xcd\xab\x89\x67\x45\x23\x01"[:],
  )
  page.entries = 1152921504606846975L
  try page.push(0) catch {
    error => assert_true(error.to_string().contains("line index exceeds"))
  } noraise {
    _ => fail("must reject unaddressable index")
  }
  assert_eq(page.used, 8)
  let writer : FailedIndexWriter = { calls: 0, }
  try page.flush(writer) catch {
    error =>
      assert_true(error.to_string().contains("injected index write failure"))
  } noraise {
    _ => fail("must propagate index write failure")
  }
  page.flush(writer)
  assert_eq(writer.calls, 1)
}

///|
async test "csplit cached matching retains byte semantics and declines crossing records" {
  let bytes = b"a\n\n\xff\x00\n" + Bytes::make(65536, b'x') + b"\ntail"
  with_snapshot(bytes, async fn(input) {
    let empty = @bytere.compile("^$")
    let binary = @bytere.compile("^..$")
    let long = @bytere.compile("^x*$")
    let tail = @bytere.compile("^tail$")
    assert_eq(input.matches_cached(0, empty.record_matcher()), None)
    assert_true(input.matches(0, @bytere.compile("^a$")))
    assert_eq(input.matches_cached(1, empty.record_matcher()), Some(true))
    assert_eq(input.matches_cached(2, binary.record_matcher()), Some(true))
    assert_eq(input.matches_cached(2, empty.record_matcher()), Some(false))
    assert_eq(input.matches_cached(3, long.record_matcher()), None)
    assert_true(input.matches(3, long))
    assert_eq(input.matches_cached(4, tail.record_matcher()), Some(true))
    assert_eq(input.matches_cached(0, empty.record_matcher()), None)
  })
  with_snapshot(Bytes::make(8194, b'\n'), async fn(input) {
    let empty = @bytere.compile("^$")
    assert_true(input.matches(8190, empty))
    assert_eq(input.matches_cached(8190, empty.record_matcher()), Some(true))
    assert_eq(input.matches_cached(8191, empty.record_matcher()), None)
    assert_true(input.matches(8191, empty))
    assert_eq(input.matches_cached(8192, empty.record_matcher()), Some(true))
  })
}

///|
async test "csplit cached scans stop at the first match or uncached record" {
  let bytes = b"head\n" + Bytes::make(65527, b'x') + b"\nhit\ntail"
  with_snapshot(bytes, async fn(input) {
    let hit = @bytere.compile("^hit$")
    let matcher = hit.record_matcher()
    assert_eq(input.search_cached(0, matcher), (0L, false))
    assert_true(input.matches(0, @bytere.compile("^head$")))
    assert_eq(
      input.search_cached(0, @bytere.compile("^head$").record_matcher()),
      (0L, true),
    )
    assert_eq(input.search_cached(0, matcher), (2L, false))
    assert_true(input.matches(2, hit))
    assert_eq(
      input.search_cached(3, @bytere.compile("^tail$").record_matcher()),
      (3L, true),
    )
    assert_eq(input.search_cached(3, matcher), (4L, false))
    assert_eq(input.search_cached(4, matcher), (4L, false))
  })
}

///|
async test "csplit byte matcher retains BRE assertions alternatives and backreferences" {
  let records = [b"head", b"", b"abab", b"word", b"\xffhit", b"last"]
  let input_bytes = b"head\n\nabab\nword\n\xffhit\nlast"
  with_snapshot(input_bytes, async fn(input) {
    for
      expression in [
        "^$", "^head$", "hit", "\\(ab\\)\\1", "\\<word\\>", ".*", "a\\|hit", "last$",
      ] {
      let pattern = @bytere.compile(expression)
      let matcher = pattern.record_matcher()
      for index, record in records {
        let expected = pattern.is_match(@bytere.text(record))
        assert_eq(input.matches(index.to_int64(), pattern), expected)
        assert_eq(
          input.matches_cached(index.to_int64(), matcher),
          Some(expected),
        )
      }
    }
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
