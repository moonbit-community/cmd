///|
async test "sort stable keys retain sequence order through external runs" {
  let root = @fs.tmpdir(prefix="sort-stable-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  @fs.write_file(input, "b alpha\nz beta\na alpha\nc beta\n".repeat(40))
  let global = test_modifiers()
  let specs = [parse_key("2,2", global)]
  let expected : &@io.Data = "b alpha\na alpha\n".repeat(40) +
    "z beta\nc beta\n".repeat(40)
  assert_eq(
    run_sort_fixture([input], global, specs~, stable=true),
    expected.binary(),
  )
  assert_eq(
    run_sort_fixture([input], global, specs~, stable=true, unique=true),
    b"b alpha\nz beta\n",
  )
}

///|
async test "sort merge preserves operand ties and assumes ordered inputs" {
  let root = @fs.tmpdir(prefix="sort-merge-")
  defer @fs.rmdir(root, recursive=true)
  let a = root + "/a"
  let b = root + "/b"
  @fs.write_file(a, "a 2\nc 1\n")
  @fs.write_file(b, "a 1\nb 3\n")
  let global = test_modifiers()
  let specs = [parse_key("1,1", global)]
  assert_eq(
    run_sort_fixture([a, b], global, merge=true),
    b"a 1\na 2\nb 3\nc 1\n",
  )
  assert_eq(
    run_sort_fixture([a, b], global, merge=true, stable=true, specs~),
    b"a 2\na 1\nb 3\nc 1\n",
  )
  assert_eq(
    run_sort_fixture([a, b], global, merge=true, unique=true, specs~),
    b"a 2\nb 3\nc 1\n",
  )
  @fs.write_file(b, "z 0\na 0\n")
  assert_eq(
    run_sort_fixture([a, b], global, merge=true),
    b"a 2\nc 1\nz 0\na 0\n",
  )
  let files : Array[String] = []
  let expected = StringBuilder()
  for index in 0..<20 {
    let file = root + "/source-" + index.to_string()
    files.push(file)
    @fs.write_file(file, "a \{index}\nb \{index}\n")
    expected.write_string("a \{index}\n")
  }
  for index in 0..<20 {
    expected.write_string("b \{index}\n")
  }
  let expected : &@io.Data = expected.to_string()
  assert_eq(
    run_sort_fixture(files, global, merge=true, stable=true, specs~),
    expected.binary(),
  )
  assert_eq(
    run_sort_fixture(files, global, merge=true, unique=true, specs~),
    b"a 0\nb 0\n",
  )
}

///|
async test "sort seeded random keys survive external runs and unique selection" {
  let root = @fs.tmpdir(prefix="sort-random-runs-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  @fs.write_file(input, "b alpha\nz beta\na alpha\nc beta\n".repeat(40))
  let global = test_modifiers()
  global.mode = Random
  let specs = [parse_key("2,2", global)]
  let seed = b"0123456789abcdef"
  let expected : &@io.Data = "b alpha\na alpha\n".repeat(40) +
    "z beta\nc beta\n".repeat(40)
  assert_eq(
    run_sort_fixture([input], global, specs~, stable=true, seed~),
    expected.binary(),
  )
  assert_eq(
    run_sort_fixture([input], global, specs~, unique=true, seed~),
    b"b alpha\nz beta\n",
  )
  @fs.write_file(input, "zeta\nalpha\nbeta\nalpha\n\n")
  assert_eq(
    run_sort_fixture([input], global, seed~),
    b"alpha\nalpha\nzeta\n\nbeta\n",
  )
}

///|
test "sort option conflicts and effective random inheritance follow GNU" {
  let random = default_modifiers(parse_args(["-RV"]))
  assert_true(random.mode == Random)
  assert_true(parse_key("2,2n", random).modifiers.mode == Numeric)
  assert_true(parse_key("2,2r", random).modifiers.mode == Lexical)
  assert_true(parse_key("2,2Rf", random).modifiers.mode == Random)
  assert_true(default_modifiers(parse_args(["--sort=random"])).mode == Random)
  assert_eq(
    one_path(parse_args(["-oout", "--output=out"]), "output", "output files"),
    Some("out"),
  )
  assert_eq(parse_args(["--", "--check=quiet"]).operands, ["--check=quiet"])
  for
    (args, name, label, expected) in [
      (
        ["-oout", "-o./out"],
        "output",
        "output files",
        "sort: multiple output files specified",
      ),
      (
        ["--random-source=a", "--random-source=b"],
        "random-source",
        "random sources",
        "sort: multiple random sources specified",
      ),
    ] {
    try one_path(parse_args(args), name, label) |> ignore catch {
      CliError(message) => assert_eq(message, expected)
      error => raise error
    } noraise {
      _ => fail("different option paths must conflict")
    }
  }
  try validate_ordering(default_modifiers(parse_args(["-Rn"]))) catch {
    CliError(message) =>
      assert_eq(message, "sort: options '-nR' are incompatible")
    error => raise error
  } noraise {
    _ => fail("random and numeric ordering must conflict")
  }
}

///|
async test "sort output aliases consume input before truncation and preserve failures" {
  let root = @fs.tmpdir(prefix="sort-output-")
  defer @fs.rmdir(root, recursive=true)
  let input = root + "/input"
  let output = root + "/output"
  @fs.write_file(input, "b\na\n")
  assert_eq(execute_sort(parse_args(["-o", input, input])), 0)
  assert_eq(@fs.read_file(input).text(), "a\nb\n")
  @fs.mkdir(root + "/directory")
  @fs.write_file(output, "KEEP\n")
  try
    execute_sort(parse_args(["-o", output, input, root + "/directory"]))
    |> ignore
  catch {
    CliError(message) => assert_true(message.has_prefix("sort: read failed:"))
    error => raise error
  } noraise {
    _ => fail("directory input must fail during reading")
  }
  assert_eq(@fs.read_file(output).text(), "KEEP\n")
  try execute_sort(parse_args(["-m", "-o", output, input])) |> ignore catch {
    CliError(message) =>
      assert_eq(
        message, "sort: unsupported capability: merge into existing output",
      )
    error => raise error
  } noraise {
    _ => fail("existing merge output requires file identity support")
  }
  assert_eq(@fs.read_file(output).text(), "KEEP\n")
  @fs.write_file(input, "b 2\na 1\n")
  assert_eq(
    execute_sort(
      parse_args([
        "-R", "-k2,2n", "--random-source=missing-seed", "-o", output, input,
      ]),
    ),
    0,
  )
  assert_eq(@fs.read_file(output).text(), "a 1\nb 2\n")
}
