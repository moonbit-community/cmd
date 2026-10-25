///|
fn compare_key(left : Bytes, right : Bytes, modifiers : Modifiers) -> Int32 {
  compare_prepared_key(
    transformed_key(left, modifiers),
    transformed_key(right, modifiers),
    modifiers,
  )
}

///|
fn test_modifiers() -> Modifiers {
  {
    ignore_leading_blanks: false,
    dictionary_order: false,
    fold_case: false,
    ignore_nonprinting: false,
    mode: Lexical,
    ordering_modes: 0,
    reverse: false,
  }
}

///|
test "key parser handles character positions and local modifiers" {
  let spec = parse_key("2.2,3.4nr", test_modifiers())
  assert_eq(spec.start.field, 2)
  assert_eq(spec.start.character, 2)
  guard spec.end is Some(end) else { fail("missing key end") }
  assert_eq(end.field, 3)
  assert_eq(end.character, 4)
  assert_true(spec.modifiers.mode == Numeric)
  assert_true(spec.modifiers.reverse)
}

///|
test "comparison modes cover numeric and text profiles" {
  let modifiers = test_modifiers()
  modifiers.mode = GeneralNumeric
  assert_true(compare_key(b"9", b"1e2", modifiers) < 0)
  assert_true(compare_key(b"text", b"0", modifiers) < 0)
  assert_true(compare_key(b"nan", b"-inf", modifiers) < 0)
  assert_true(compare_key(b"1", b"inf", modifiers) < 0)
  modifiers.mode = HumanNumeric
  assert_true(compare_key(b"10K", b"2M", modifiers) < 0)
  assert_true(compare_key(b"999999K", b"1M", modifiers) < 0)
  modifiers.mode = Month
  assert_true(compare_key(b"JAN", b"Feb", modifiers) < 0)
  modifiers.mode = Version
  assert_true(compare_key(b"file2", b"file10", modifiers) < 0)
  assert_true(compare_key(b"file~1", b"file1", modifiers) < 0)
}

///|
test "C-locale transformations are byte based" {
  let modifiers = test_modifiers()
  modifiers.dictionary_order = true
  modifiers.fold_case = true
  modifiers.ignore_nonprinting = true
  assert_eq(transformed_key(b" A-\x01b!", modifiers), b" AB")
}

///|
test "blank separated fields retain their leading separators" {
  let spec = parse_key("2,2", test_modifiers())
  assert_eq(extract_key(b"x  b", spec, None), b"  b")
}

///|
test "ordering modifiers on both key positions are combined" {
  let spec = parse_key("2n,2r", test_modifiers())
  assert_true(spec.modifiers.mode == Numeric)
  assert_true(spec.modifiers.reverse)
}

///|
async fn run_sort_fixture(
  files : Array[String],
  modifiers : Modifiers,
  unique~ : Bool = false,
  delimiter~ : Byte = b'\n',
  specs~ : Array[KeySpec] = [],
  stable~ : Bool = false,
  merge~ : Bool = false,
  seed~ : Bytes = b"",
  budget~ : Int64 = 22 * 65536 + 512,
  fan_in~ : Int32 = 16,
  temporary_directories~ : Array[String] = [],
) -> Bytes {
  let output = @io.MemoryReader(writer => {
    let status = sort_sources(
      files,
      writer,
      delimiter,
      specs,
      modifiers,
      None,
      unique~,
      stable~,
      merge~,
      seed~,
      budget~,
      fan_in~,
      temporary_directories~,
    )
    assert_eq(status, 0)
  })
  defer output.close()
  output.read_all().binary()
}

///|
test "sort resource controls parse units maxima and protected option values" {
  assert_eq(buffer_size("0"), 0L)
  assert_eq(buffer_size("2"), 2048L)
  assert_eq(buffer_size("2b"), 2L)
  assert_eq(buffer_size("M"), 1048576L)
  assert_eq(buffer_size("+2G"), 2147483648L)
  assert_eq(buffer_size("0Q"), 0L)
  assert_eq(buffer_size("0%"), 0L)
  assert_eq(resource_controls(parse_args(["--buffer-size=0%"])), (0L, 16))
  let parsed = parse_args([
    "-S1M", "--buffer-size=2b", "-S", "0", "--batch-size=2", "-T", "--check=quiet",
    "--temporary-directory=other",
  ])
  assert_eq(resource_controls(parsed), (1048576L, 2))
  assert_eq(parsed.values("temporary-directory"), ["--check=quiet", "other"])
  assert_true(!parsed.contains("check-quiet"))
  assert_eq(
    resource_controls(parse_args(["--batch-size=2", "--batch-size=32"])),
    (67108864L, 16),
  )
}

///|
test "sort resource controls reject invalid overflow and percentage requests" {
  for
    value in [
      "", "-1", "1.5M", "1MB", "1KiB", "b", "1Z", "9223372036854775808b",
    ] {
    try buffer_size(value) |> ignore catch {
      CliError(_) => ()
    } noraise {
      _ => fail("invalid buffer size accepted: " + value)
    }
  }
  try buffer_size("20%") |> ignore catch {
    CliError(message) =>
      assert_true(message.has_prefix("sort: unsupported capability:"))
  } noraise {
    _ => fail("physical-memory boundary must reject")
  }
  for value in ["0", "1", "2K", "-2"] {
    try
      resource_controls(parse_args(["--batch-size=" + value])) |> ignore
    catch {
      CliError(_) => ()
      error => raise error
    } noraise {
      _ => fail("invalid batch size accepted: " + value)
    }
  }
}

///|
test "sort merge accounting does not overflow near signed 64-bit budgets" {
  let runs = [
    { path: "a", largest_entry: 9223372036854775807L, level: 0, },
    { path: "b", largest_entry: 9223372036854775807L, level: 0, },
    { path: "c", largest_entry: 1L, level: 0, },
  ]
  assert_eq(merge_count(runs, 9223372036854775807L), 2)
  assert_eq(merge_count(runs, 1L, fan_in=2), 2)
}

///|
async test "sort fan-in two retains oversized stable records and cleans multiple directories" {
  let root = @fs.tmpdir(prefix="sort-resource-controls-")
  defer @fs.rmdir(root, recursive=true)
  let first = root + "/first"
  let second = root + "/second"
  @fs.mkdir(first)
  @fs.mkdir(second)
  let path = root + "/input"
  let long = "x".repeat(70000)
  @fs.write_file(path, "2 first\n1 " + long + "\n2 second\n1 short\n2 third\n")
  let modifiers = test_modifiers()
  modifiers.mode = Numeric
  assert_eq(
    run_sort_fixture([path], modifiers, stable=true, budget=0, fan_in=2, temporary_directories=[
      first, second,
    ]),
    @utf8.encode("1 " + long + "\n1 short\n2 first\n2 second\n2 third\n"),
  )
  assert_eq(
    run_sort_fixture([path], modifiers, unique=true, budget=0, fan_in=2, temporary_directories=[
      first, second,
    ]),
    @utf8.encode("1 " + long + "\n2 first\n"),
  )
  assert_eq(@fs.readdir(first), [])
  assert_eq(@fs.readdir(second), [])
  // An unused directory is not opened when all records remain in memory.
  assert_eq(
    run_sort_fixture(
      [path],
      modifiers,
      stable=true,
      temporary_directories=[root + "/absent"],
      budget=67108864,
    ),
    @utf8.encode("1 " + long + "\n1 short\n2 first\n2 second\n2 third\n"),
  )
}

///|
async test "sort selected fan-in preserves merge source order and prepared random keys" {
  let root = @fs.tmpdir(prefix="sort-fanin-merge-")
  defer @fs.rmdir(root, recursive=true)
  let sources = [root + "/a", root + "/b", root + "/c"]
  for index, path in sources {
    @fs.write_file(
      path,
      "1 " + index.to_string() + "\n2 " + index.to_string() + "\n",
    )
  }
  let numeric = test_modifiers()
  numeric.mode = Numeric
  assert_eq(
    run_sort_fixture(
      sources,
      numeric,
      merge=true,
      stable=true,
      fan_in=2,
      budget=0,
    ),
    b"1 0\n1 1\n1 2\n2 0\n2 1\n2 2\n",
  )
  let random = test_modifiers()
  random.mode = Random
  let seed = b"0123456789abcdef"
  assert_eq(
    run_sort_fixture(sources, random, fan_in=2, budget=0, seed~),
    run_sort_fixture(sources, random, budget=67108864, seed~),
  )
}

///|
async test "sort temporary run paths rotate between explicitly selected parents" {
  let root = @fs.tmpdir(prefix="sort-temp-parents-")
  defer @fs.rmdir(root, recursive=true)
  let parents = [root + "/a", root + "/b"]
  for parent in parents {
    @fs.mkdir(parent)
  }
  let spool : Spool = { directories: parents, roots: [None, None], next: 0, }
  defer (for child in spool.roots {
    if child is Some(child) {
      @fs.rmdir(child, recursive=true)
    }
  })
  let first = spool.path()
  let second = spool.path()
  let third = spool.path()
  assert_true(first.has_prefix(parents[0] + "/cli-sort-"))
  assert_true(second.has_prefix(parents[1] + "/cli-sort-"))
  assert_true(third.has_prefix(parents[0] + "/cli-sort-"))
  assert_eq(first[:first.length() - 1], third[:third.length() - 1])
}

///|
async test "sort temporary parent failure cleans owned runs and preserves output" {
  let root = @fs.tmpdir(prefix="sort-temp-failure-")
  defer @fs.rmdir(root, recursive=true)
  let first = root + "/first"
  @fs.mkdir(first)
  @fs.write_file(first + "/keep", "unowned\n")
  let input = root + "/input"
  let output = root + "/output"
  @fs.write_file(input, "c\nb\na\n")
  @fs.write_file(output, "KEEP\n")
  // Each record becomes a run: the second spill reaches the missing parent.
  try
    execute_sort(
      parse_args([
        "-S0b",
        "--batch-size=2",
        "-T",
        first,
        "-T",
        root + "/missing",
        "-o",
        output,
        input,
      ]),
    )
    |> ignore
  catch {
    @os_error.OSError(_) as error => assert_true(error.is_ENOENT())
    error => raise error
  } noraise {
    _ => fail("the second temporary parent must fail")
  }
  assert_eq(@fs.read_file(output).binary(), b"KEEP\n")
  assert_eq(@fs.readdir(first), ["keep"])
  assert_eq(@fs.read_file(first + "/keep").binary(), b"unowned\n")
}

///|
priv suberror SortRunWriteFailure

///|
priv struct SortPrefixWriter {
  bytes : Array[Byte]
  mut remaining : Int32
  mut calls : Int32
}

///|
impl @io.Writer for SortPrefixWriter with fn write_once(
  self,
  data,
  offset~,
  len~,
) {
  self.calls += 1
  guard self.remaining > 0 else { raise SortRunWriteFailure }
  let count = self.remaining.min(len)
  for byte in data[offset:offset + count] {
    self.bytes.push(byte)
  }
  self.remaining -= count
  count
}

///|
async test "sort temporary entry writes propagate a partial writer failure" {
  let writer : SortPrefixWriter = { bytes: [], remaining: 14, calls: 0, }
  let entry : Entry = { record: b"record", keys: [b"key"], index: 7, }
  try write_entry(writer, entry) catch {
    SortRunWriteFailure => ()
    error => raise error
  } noraise {
    _ => fail("the temporary entry writer must propagate failure")
  }
  assert_eq(writer.bytes.length(), 14)
  assert_eq(Bytes::from_array(writer.bytes)[12:], b"re"[:])
  assert_eq(writer.calls, 3)
}

///|
async test "sort named merge output stays empty until all sources are safely spooled" {
  let root = @fs.tmpdir(prefix="sort-merge-output-safety-")
  defer @fs.rmdir(root, recursive=true)
  let source = root + "/input"
  let target = root + "/output"
  @fs.write_file(source, "a\nb\n")
  prepare_output(target, true)
  let failed = Ref(false)
  let output = @io.MemoryReader(writer => {
    try
      sort_sources(
        [source, root],
        writer,
        b'\n',
        [],
        test_modifiers(),
        None,
        unique=false,
        merge=true,
        output_path=Some(target),
        fan_in=2,
      )
      |> ignore
    catch {
      CliError(_) => failed.val = true
      error => raise error
    }
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"")
  assert_true(failed.val)
  assert_eq(@fs.read_file(target).binary(), b"")
  try prepare_output(source, true) catch {
    CliError(message) =>
      assert_true(message.has_prefix("sort: unsupported capability:"))
    error => raise error
  } noraise {
    _ => fail("existing merge output must reject")
  }
  assert_eq(@fs.read_file(source).binary(), b"a\nb\n")
}

///|
async test "sort external rounds preserve ordering and first unique representative" {
  let root = @fs.tmpdir(prefix="sort-external-rounds-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/input"
  @fs.write_file(path, "2 first\n1 only\n2 second\n".repeat(400))
  let numeric = test_modifiers()
  numeric.mode = Numeric
  let expected : &@io.Data = "1 only\n".repeat(400) +
    "2 first\n".repeat(400) +
    "2 second\n".repeat(400)
  assert_eq(run_sort_fixture([path], numeric), expected.binary())
  assert_eq(
    run_sort_fixture([path], numeric, unique=true),
    b"1 only\n2 first\n",
  )
  numeric.reverse = true
  assert_eq(
    run_sort_fixture([path], numeric, unique=true),
    b"2 first\n1 only\n",
  )
  assert_eq(
    run_sort_fixture([path], test_modifiers(), unique=true, specs=[
      parse_key("2,2f", test_modifiers()),
    ]),
    b"2 first\n1 only\n2 second\n",
  )
}

///|
async test "sort external records preserve binary NUL delimiters and missing final delimiter" {
  let root = @fs.tmpdir(prefix="sort-external-binary-")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/a", b"z\xff\x00a\n\x00")
  @fs.write_file(root + "/b", b"m\x00a\n")
  assert_eq(
    run_sort_fixture(
      [root + "/a", root + "/b"],
      test_modifiers(),
      delimiter=b'\x00',
    ),
    b"a\n\x00a\n\x00m\x00z\xff\x00",
  )
}

///|
async test "sort validates all sources before emitting records and streams check mode" {
  let root = @fs.tmpdir(prefix="sort-external-errors-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/input"
  @fs.write_file(path, "a\nb\nc\n".repeat(100))
  let failed = Ref(false)
  let output = @io.MemoryReader(writer => {
    let _ = sort_sources(
      [path, root + "/missing"],
      writer,
      b'\n',
      [],
      test_modifiers(),
      None,
      unique=false,
      budget=22 * 65536 + 512,
    ) catch {
      _ => {
        failed.val = true
        1
      }
    }
  })
  defer output.close()
  assert_eq(output.read_all().binary(), b"")
  assert_true(failed.val)
  let check_output = @io.MemoryReader(writer => {
    assert_eq(
      sort_sources(
        [path],
        writer,
        b'\n',
        [],
        test_modifiers(),
        None,
        unique=false,
        check=true,
      ),
      1,
    )
  })
  defer check_output.close()
  assert_eq(check_output.read_all().binary(), b"")
}

///|
async test "sort temporary run reader rejects truncated and corrupt lengths" {
  let root = @fs.tmpdir(prefix="sort-external-corruption-")
  defer @fs.rmdir(root, recursive=true)
  let path = root + "/run"
  for bytes in [b"short", b"\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff"] {
    @fs.write_file(path, bytes)
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    let reader : RunReader = {
      file,
      buffer: FixedArray::make(65536, b'\x00'),
      position: 0,
      available: 0,
      limit: 256,
      key_count: 1,
    }
    try reader.next() |> ignore catch {
      CliError(_) => ()
      error => raise error
    } noraise {
      _ => fail("corrupt run must fail")
    }
  }
}
