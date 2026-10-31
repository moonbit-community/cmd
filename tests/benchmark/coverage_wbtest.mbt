// Synthetic and codec fixtures below verify test-tool correctness. They do not
// register timing workloads or establish real-source performance coverage.

///|
async test "clustered and cyclic mixtures preserve complete histograms while changing order" {
  let directory = @fs.tmpdir(prefix="cmd-clustered-mixtures-")
  defer @fs.rmdir(directory, recursive=true)
  let widths : Array[Array[Int32]] = []
  let histograms : Array[Map[Int32, Int32]] = []
  for shape in ["mixed-short-ascii-v1", "mixed-short-clustered-ascii-v1"] {
    write_corpus(directory + "/" + shape, {
      bytes: 204800L,
      record_bytes: 4096L,
      shape,
    })
    let rows = @fs.read_file(directory + "/" + shape)
      .text()
      .split("\n")
      .filter(line => !line.is_empty())
      .map(line => line.length() + 1)
      .to_array()
    assert_eq(rows.length(), 2072)
    let counts : Map[Int32, Int32] = Map([])
    let mut bytes = 0
    let mut short_bytes = 0
    for width in rows {
      counts[width] = counts.get(width).unwrap_or(0) + 1
      bytes += width
      if width <= 128 {
        short_bytes += width
      }
    }
    assert_eq(bytes, 204800)
    assert_eq(short_bytes, 163840)
    histograms.push(counts)
    widths.push(rows)
  }
  assert_eq(histograms[0], histograms[1])
  assert_eq(
    histograms[0],
    Map([(32, 512), (64, 512), (96, 512), (128, 512), (512, 16), (4096, 8)]),
  )
  assert_true(widths[0] != widths[1])
  assert_eq(widths[0][:4], [32, 64, 96, 128][:])
  assert_eq(widths[1][:8], Array::make(8, 4096)[:])
}

///|
async test "large JSON values span multiple input chunks and preserve complete record validation" {
  let directory = @fs.tmpdir(prefix="cmd-large-json-values-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 524288L,
    record_bytes: 131072L,
    shape: "nested-large-jsonl-v1",
  }
  write_corpus(directory + "/input", spec)
  let rows = @fs.read_file(directory + "/input")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(rows.length(), 4)
  for index, line in rows {
    assert_eq(line.length(), 131071)
    let parsed = @json.parse(line.to_owned())
    guard parsed is Object(fields) else {
      fail("large JSON record is not an object")
    }
    let mut leaf = fields["meta"]
    let mut depth = 0
    while leaf is Object(object) {
      leaf = object["n"]
      depth += 1
    }
    assert_eq(depth, [4, 8, 16, 32][index])
    guard leaf is String(value) else { fail("large JSON leaf is not a string") }
    assert_true(value.length() > 65536)
    for marker in ["π", "\t", "\"", "\\"] {
      assert_true(value.contains(marker))
    }
    assert_true(line[65536] != ('\n' : UInt16))
  }
  let before = @fs.read_file(directory + "/input").binary()
  let generated = Some(
    write_corpus(directory + "/input", { ..spec, bytes: spec.bytes - 1L, }),
  ) catch {
    _ => None
  }
  assert_true(generated is None)
  assert_eq(@fs.read_file(directory + "/input").binary(), before)
}

///|
async test "nested JSON corpus covers deep objects long escaped Unicode values and chunk crossings" {
  let directory = @fs.tmpdir(prefix="cmd-nested-json-modes-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 81920L,
    record_bytes: 4096L,
    shape: "nested-jsonl-v1",
  }
  write_corpus(directory + "/input", spec)
  let lines = @fs.read_file(directory + "/input")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(lines.length(), 20)
  for index, line in lines {
    assert_eq(line.length(), 4095)
    let parsed = @json.parse(line.to_owned())
    guard parsed is Object(fields) else {
      fail("nested JSON record is not an object")
    }
    assert_eq(fields["name"], Json("large"))
    assert_eq(fields["active"], Json(index % 2 == 0))
    let mut node = fields["meta"]
    let mut depth = 0
    while node is Object(object) {
      node = object["n"]
      depth += 1
    }
    assert_eq(depth, [4, 8, 16, 32][index % 4])
    guard node is String(value) else {
      fail("nested JSON leaf is not a string")
    }
    assert_true(value.length() > 1000)
    for marker in ["π", "\t", "\"", "\\"] {
      assert_true(value.contains(marker))
    }
  }
  let before = @fs.read_file(directory + "/input").binary()
  let accepted = Some(
    write_corpus(directory + "/input", { ..spec, bytes: spec.bytes + 1L, }),
  ) catch {
    _ => None
  }
  assert_true(accepted is None)
  assert_eq(@fs.read_file(directory + "/input").binary(), before)
}

///|
async test "short mixed data is byte dominated by ordinary rows across chunk boundaries" {
  let directory = @fs.tmpdir(prefix="cmd-short-mixture-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 76800L,
    record_bytes: 4096L,
    shape: "mixed-short-ascii-v1",
  }
  write_corpus(directory + "/input", spec)
  let lines = @fs.read_file(directory + "/input")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(lines.length(), 777)
  let mut total = 0
  let mut short = 0
  let counts : Map[Int32, Int32] = Map([])
  for line in lines {
    let width = line.length() + 1
    total += width
    if width <= 128 {
      short += width
    }
    counts[width] = counts.get(width).unwrap_or(0) + 1
  }
  assert_eq(total, 76800)
  assert_eq(short, 61440)
  assert_eq(
    counts,
    Map([(32, 192), (64, 192), (96, 192), (128, 192), (512, 6), (4096, 3)]),
  )
  assert_true(
    corpus_spec_errors({ ..spec, record_bytes: 65537L, }).length() > 0,
  )
}

///|
async test "section corpus contains multiple separated interior split boundaries" {
  let directory = @fs.tmpdir(prefix="cmd-section-mixture-")
  defer @fs.rmdir(directory, recursive=true)
  let spec : CorpusSpec = {
    bytes: 656000L,
    record_bytes: 80L,
    shape: "sections-ascii-v1",
  }
  write_corpus(directory + "/input", spec)
  let text = @fs.read_file(directory + "/input").text()
  let lines = text.split("\n").filter(line => !line.is_empty()).to_array()
  assert_eq(lines.length(), 8200)
  assert_eq(lines.filter(line => line.has_prefix("SECTION ")).length(), 3)
  for index in [0, 4096, 8192] {
    assert_true(lines[index].has_prefix("SECTION "))
  }
  assert_false(lines[1].has_prefix("SECTION "))
}

///|
async test "tab conversion and column grid inputs activate their declared modes" {
  let directory = @fs.tmpdir(prefix="cmd-active-text-modes-")
  defer @fs.rmdir(directory, recursive=true)
  write_corpus(directory + "/tabs", {
    bytes: 5120L,
    record_bytes: 80L,
    shape: "tabs-spaces-v1",
  })
  let records = @fs.read_file(directory + "/tabs")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(records.length(), 64)
  for line in records {
    assert_true(line.has_prefix("alpha        beta\t"))
  }
  write_corpus(directory + "/cells", {
    bytes: 1024L,
    record_bytes: 16L,
    shape: "short-cells-v1",
  })
  let cells = @fs.read_file(directory + "/cells")
    .text()
    .split("\n")
    .filter(line => !line.is_empty())
    .to_array()
  assert_eq(cells.length(), 64)
  for cell in cells {
    assert_eq(cell.length(), 15)
    assert_false(cell.contains(" ") || cell.contains("\t"))
    assert_true(2 * (cell.length() + 2) <= 80)
  }
}

///|
async test "file benchmark recipes preserve equal identity distinction and activate edits overlap and duplicates" {
  let directory = @fs.tmpdir(prefix="cmd-file-recipes-")
  defer @fs.rmdir(directory, recursive=true)
  let source = directory + "/source"
  write_corpus(source, {
    bytes: 160000L,
    record_bytes: 80L,
    shape: "varied-ascii-v1",
  })
  let prepared : PreparedCorpus = { source, input: source, }
  for
    recipe in [
      "bench-diff-equal", "bench-diff-sparse-edit", "bench-diff-distributed-edit",
      "bench-join-mixed", "bench-join-duplicates", "bench-comm-mixed",
    ] {
    let command = benchmark_recipe_command(recipe).unwrap()
    let workload : FunctionalWorkload = @json.from_json({
      "id": recipe,
      "command": command,
      "reference_behavior_id": "fixture",
      "recipe": recipe,
    })
    let fixture = functional_fixture(workload, [], "helper")
    let root = directory + "/" + recipe
    @fs.mkdir(root)
    prepare_benchmark_recipe(workload, Some(prepared), root)
    assert_true(@fs.realpath(root + "/left") != @fs.realpath(root + "/right"))
    if recipe == "bench-diff-equal" {
      assert_true(files_equal(root + "/left", root + "/right"))
      assert_eq(fixture.expected_status, 0)
    } else if recipe.has_prefix("bench-diff-") {
      assert_false(files_equal(root + "/left", root + "/right"))
      assert_true(files_equal(root + "/left", source))
      assert_eq(fixture.expected_status, 1)
    } else {
      let left = @fs.read_file(root + "/left")
        .text()
        .split("\n")
        .filter(line => !line.is_empty())
        .map(line => line.to_owned())
        .to_array()
      let right = @fs.read_file(root + "/right")
        .text()
        .split("\n")
        .filter(line => !line.is_empty())
        .map(line => line.to_owned())
        .to_array()
      let left_keys = left.map(line => {
        line.split(" ").next().unwrap().to_owned()
      })
      let right_keys = right.map(line => {
        line.split(" ").next().unwrap().to_owned()
      })
      if recipe == "bench-join-duplicates" {
        assert_eq(left_keys[0:4], Array::make(4, left_keys[0])[:])
        assert_eq(right_keys[0:3], Array::make(3, right_keys[0])[:])
        assert_eq(left_keys[0], right_keys[0])
        assert_true(left_keys[4] != left_keys[0])
      } else {
        assert_true(left_keys.any(key => right_keys.contains(key)))
        assert_true(left_keys.any(key => !right_keys.contains(key)))
        assert_true(right_keys.any(key => !left_keys.contains(key)))
      }
    }
  }
}

///|
async test "explicit stored fixed and concatenated gzip fixture modes roundtrip across block boundaries" {
  let directory = @fs.tmpdir(prefix="cmd-gzip-modes-")
  defer @fs.rmdir(directory, recursive=true)
  let source = directory + "/source"
  @fs.write_file(source, Bytes::makei(131075, i => (i % 256).to_byte()))
  for mode in ["stored", "fixed-literals", "members"] {
    let encoded = directory + "/" + mode + ".gz"
    prepare_benchmark_gzip_input(mode, source, encoded, "unused", Map([]), 1000)
    let file = @fs.open(encoded, mode=ReadOnly)
    let header = file.read_exactly_at(11, position=0L)
    file.close()
    assert_eq(
      (header[10].to_int() >> 1) & 3,
      if mode == "fixed-literals" {
        1
      } else {
        0
      },
    )
    assert_true(gzip_roundtrip(encoded, source, directory + "/decoded"))
  }
  let empty = directory + "/empty"
  @fs.write_file(empty, b"")
  for mode in ["stored", "fixed-literals"] {
    let encoded = directory + "/empty-" + mode
    write_benchmark_gzip(empty, encoded, mode)
    assert_true(gzip_roundtrip(encoded, empty, directory + "/empty-decoded"))
  }
}

///|
async test "fixed backreference controls preserve overlap full-window distances tails and checksums" {
  let directory = @fs.tmpdir(prefix="cmd-fixed-backrefs-")
  defer @fs.rmdir(directory, recursive=true)
  for
    (shape, width, mode, distance) in [
      ("backref-one-v1", 1L, "fixed-backref-one", 1),
      ("backref-window-v1", 32768L, "fixed-backref-window", 32768),
    ] {
    let source = directory + "/" + shape
    write_corpus(source, { bytes: 131075L, record_bytes: width, shape, })
    let encoded = source + ".gz"
    prepare_benchmark_gzip_input(mode, source, encoded, "unused", Map([]), 1000)
    let compressed = @fs.open(encoded, mode=ReadOnly)
    let header = compressed.read_exactly_at(11, position=0L)
    compressed.close()
    assert_eq((header[10].to_int() >> 1) & 3, 1)
    assert_true(gzip_roundtrip(encoded, source, directory + "/decoded"))
    let decoded = @fs.open(directory + "/decoded", mode=ReadOnly)
    for at in [32767L, 32768L, 32769L, 65535L, 65536L, 65537L, 131074L] {
      let expected = if distance == 1 {
        b'a'
      } else {
        benchmark_window_byte(at)
      }
      assert_eq(
        decoded.read_exactly_at(1, position=at),
        Bytes::make(1, expected),
      )
    }
    decoded.close()
    let features = @json.parse(@fs.read_file(encoded + ".features.json").text())
    assert_true(
      features
      is { "deflate_block": String("fixed"), "source_validated": True, .. },
    )
    let checksum_source = @fs.open(encoded, mode=ReadOnly)
    let checksum_byte = checksum_source.read_exactly_at(
        1,
        position=@fs.file_size(encoded) - 8L,
      )[0]
    checksum_source.close()
    let corrupt = @fs.open(encoded, mode=WriteOnly)
    corrupt.write_at(
      Bytes::make(1, (checksum_byte.to_int() ^ 1).to_byte()),
      position=@fs.file_size(encoded) - 8L,
    )
    corrupt.close()
    let accepted = gzip_roundtrip(
      encoded,
      source,
      directory + "/corrupt-decoded",
    ) catch {
      _ => false
    }
    assert_false(accepted)
    @fs.write_file(encoded, b"preserve prior fixture")
    let wrong = directory + "/wrong"
    @fs.write_file(wrong, Bytes::make(32769, b'z'))
    let generated = Some(write_benchmark_backref_gzip(wrong, encoded, distance)) catch {
      _ => None
    }
    assert_true(generated is None)
    assert_eq(@fs.read_file(encoded).binary(), b"preserve prior fixture")
  }
}
