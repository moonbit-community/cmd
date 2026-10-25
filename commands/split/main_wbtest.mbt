///|
async fn split_fixture(
  input : Bytes,
  args : Array[String],
) -> (Int32, Array[(String, Bytes)]) {
  let directory = @fs.tmpdir(prefix="split-test-")
  defer @fs.rmdir(directory, recursive=true)
  let parsed = parse_args([..args, "-", directory + "/p"])
  let reader = @io.MemoryReader(writer => writer.write(input))
  defer reader.close()
  let status = try {
    process(reader, options(parsed), Some(input.length().to_int64()))
    0
  } catch {
    SplitError(status, _) => status
    error => raise error
  }
  let files : Array[(String, Bytes)] = []
  for name in @fs.readdir(directory, sort=true) {
    files.push((name, @fs.read_file(directory + "/" + name).binary()))
  }
  (status, files)
}

///|
fn invalid_options(args : Array[String]) -> String raise @cli.CliError {
  let parsed = parse_args(args)
  try {
    ignore(options(parsed))
    "accepted"
  } catch {
    SplitError(_, message) => message
  }
}

///|
test "split counts complete records while preserving partial and binary records" {
  assert_eq(byte_count("2K"), 2048L)
  assert_eq(byte_count("2kB"), 2000L)
  assert_eq(byte_count("3G"), 3221225472L)
  assert_eq(partition_end(10L, 3L, 0L), 4L)
  assert_eq(partition_end(10L, 3L, 1L), 7L)
  assert_eq(partition_index(11L, 3L, 8L), 2L)
}

///|
test "split expands default suffixes and exhausts explicit widths" {
  let letters = [24, 25]
  assert_true(advance_suffix(letters, 26, true))
  assert_eq(suffix_name(letters, "abcdefghijklmnopqrstuvwxyz"), "zaaa")
  let numbers = [8, 9]
  assert_true(advance_suffix(numbers, 10, true))
  assert_eq(suffix_name(numbers, "0123456789"), "9000")
  assert_true(!advance_suffix([25, 25], 26, false))
  let names = Names::new(options(parse_args(["--hex-suffixes=a"])))
  assert_eq(names.next(), "x0a")
  assert_eq(names.next(), "x0b")
}

///|
async test "split streams byte and record pieces without losing binary tails" {
  assert_eq(
    split_fixture(b"\x00\xff\na", ["-b2"]),
    (0, [("paa", b"\x00\xff"), ("pab", b"\na")]),
  )
  assert_eq(
    split_fixture(b"a\nb\nc", ["-l2"]),
    (0, [("paa", b"a\nb\n"), ("pab", b"c")]),
  )
  assert_eq(split_fixture(b"", ["-b2"]), (0, []))
}

///|
async test "split chunk allocation keeps empty partitions and elides compressed names" {
  assert_eq(
    split_fixture(b"0123456789", ["-n3"]),
    (0, [("paa", b"0123"), ("pab", b"456"), ("pac", b"789")]),
  )
  assert_eq(
    split_fixture(b"A\nBBBBB\nC\nD", ["-nl/3"]),
    (0, [("paa", b"A\nBBBBB\n"), ("pab", b""), ("pac", b"C\nD")]),
  )
  assert_eq(
    split_fixture(b"123456789\nx\n", ["-enl/3"]),
    (0, [("paa", b"123456789\n"), ("pab", b"x\n")]),
  )
  assert_eq(
    split_fixture(b"", ["-n3"]),
    (0, [("paa", b""), ("pab", b""), ("pac", b"")]),
  )
  assert_eq(split_fixture(b"", ["-en9223372036854775807"]), (0, []))
}

///|
async test "split round robin and line-byte modes retain record boundaries" {
  assert_eq(
    split_fixture(b"a\nb\nc\nd\ne", ["-nr/3"]),
    (0, [("paa", b"a\nd\n"), ("pab", b"b\ne"), ("pac", b"c\n")]),
  )
  assert_eq(
    split_fixture(b"ab\n12345678\nz\n", ["-C5"]),
    (
      0,
      [("paa", b"ab\n"), ("pab", b"12345"), ("pac", b"678\n"), ("pad", b"z\n")],
    ),
  )
}

///|
async test "split suffix starts and exhaustion retain completed pieces" {
  assert_eq(
    split_fixture(b"abcd", ["-b1", "--numeric-suffixes=0008"]),
    (0, [("p08", b"a"), ("p09", b"b"), ("p10", b"c"), ("p11", b"d")]),
  )
  assert_eq(
    split_fixture(b"abc", ["-b1", "--numeric-suffixes=98"]),
    (1, [("p98", b"a"), ("p99", b"b")]),
  )
  assert_eq(
    split_fixture(b"abc", ["-b1", "--hex-suffixes=9"]),
    (0, [("p09", b"a"), ("p0a", b"b"), ("p0b", b"c")]),
  )
  assert_eq(
    split_fixture(b"abc", ["-b1", "--hex-suffixes=a"]),
    (0, [("p0a", b"a"), ("p0b", b"b"), ("p0c", b"c")]),
  )
}

///|
test "split rejects conflicting methods and selected-chunk filters before input" {
  assert_eq(
    invalid_options(["-n3", "-n3"]),
    "cannot split in more than one way\nTry 'split --help' for more information.",
  )
  assert_eq(
    invalid_options(["-C2", "-n3"]),
    "cannot split in more than one way\nTry 'split --help' for more information.",
  )
  assert_eq(
    invalid_options(["-n2/3", "--filter="]),
    "--filter does not process a chunk extracted to standard output\nTry 'split --help' for more information.",
  )
  assert_eq(
    invalid_options(["-n27", "-a1"]),
    "the suffix length needs to be at least 2",
  )
}

///|
async test "split filters receive FILE and distinguish nonreading success from exit141" {
  assert_eq(
    split_fixture(b"abcd", ["-b2", "--filter=printf marker > \"$FILE\""]),
    (0, [("paa", b"marker"), ("pab", b"marker")]),
  )
  assert_eq(
    split_fixture(Bytes::make(131072, b'x'), ["-b65536", "--filter="]),
    (0, []),
  )
  assert_eq(split_fixture(b"abcd", ["-b2", "--filter=exit 141"]), (141, []))
}
