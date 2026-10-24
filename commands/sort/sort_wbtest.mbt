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
      budget=22 * 65536 + 512,
    )
    assert_eq(status, 0)
  })
  defer output.close()
  output.read_all().binary()
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
