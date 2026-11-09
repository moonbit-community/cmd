///|
async fn independently_decode_gzip(data : Bytes) -> Bytes {
  let input = @io.MemoryReader(writer => writer.write(data))
  defer input.close()
  @gzip.Decoder(input).read_all().binary()
}

///|
async fn compression_selectors_scenario(root : String, work : String) -> Unit {
  let original = @utf8.encode(
      "abracadabra 0123456789 abracadabra\n".repeat(512),
    ) +
    b"\x00\xfftail"
  @fs.write_file(work + "/payload", original)
  for level in 1..<=9 {
    let spelling = if level == 1 {
      "--fast"
    } else if level == 9 {
      "--best"
    } else {
      "-" + level.to_string()
    }
    let overridden = if level == 1 { "--best" } else { "--fast" }
    let encoded = scenario_run(
      work,
      root,
      "gzip",
      ["-cn", spelling, "payload"],
      cwd=work,
    )
    assert_eq(encoded.status, 0)
    assert_eq(encoded.stderr, b"")
    assert_true(encoded.stdout.length() < original.length())
    let decoded = independently_decode_gzip(encoded.stdout)
    assert_eq(decoded, original)
    assert_eq(
      encoded.stdout[:8].to_owned(),
      b"\x1f\x8b\x08\x00\x00\x00\x00\x00",
    )
    let extra = if level == 1 { 4 } else if level == 9 { 2 } else { 0 }
    assert_eq(encoded.stdout[8].to_int(), extra)
    let repeated = scenario_run(
      work,
      root,
      "gzip",
      ["-cn", overridden, spelling, "payload"],
      cwd=work,
    )
    assert_eq(repeated.status, 0)
    assert_eq(repeated.stderr, b"")
    assert_eq(repeated.stdout, encoded.stdout)
    let retained = @fs.read_file(work + "/payload").binary()
    assert_eq(retained, original)

    @harness.assert_observation(
      "gzip/level-" + level.to_string(),
      "gzip",
      {
        "status": encoded.status,
        "stderr": @harness.scenario_text(encoded.stderr),
        "decoded": decoded == original,
        "metadata_omitted": encoded.stdout[:8].to_owned() ==
        b"\x1f\x8b\x08\x00\x00\x00\x00\x00",
        "extra_flags": encoded.stdout[8].to_int(),
        "compressed": encoded.stdout.length() < original.length(),
        "last_value": repeated.stdout == encoded.stdout,
        "retained": retained == original,
      },
      {
        "status": 0,
        "stderr": "",
        "decoded": true,
        "metadata_omitted": true,
        "extra_flags": extra,
        "compressed": true,
        "last_value": true,
        "retained": true,
      },
    )
  }
  let rejected = scenario_run(work, root, "gzip", ["-c", "payload"], cwd=work)
  assert_eq(rejected.status, 2)
  assert_eq(rejected.stdout, b"")
  assert_eq(
    rejected.stderr,
    b"gzip: saved filename metadata is unsupported; use -n\n",
  )
  assert_eq(@fs.read_file(work + "/payload").binary(), original)

  @harness.assert_observation(
    "gzip/name-boundary",
    "gzip",
    {
      "status": rejected.status,
      "stdout": @harness.scenario_text(rejected.stdout),
      "stderr": @harness.scenario_text(rejected.stderr),
    },
    {
      "status": 2,
      "stdout": "",
      "stderr": "gzip: saved filename metadata is unsupported; use -n\n",
    },
  )
}
