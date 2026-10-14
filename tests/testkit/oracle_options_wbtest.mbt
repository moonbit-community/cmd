///|
test "oracle CLI options preserve defaults and select explicit staged profiles" {
  let defaults = parse_oracle_options(["--suite", "contract"][:])
  assert_eq(defaults.profile_path, "tests/runner/image/profile.json")
  assert_eq(defaults.arguments, ["--suite", "contract"])
  assert_eq(defaults.seal_digest, None)
  let digest = "sha256:" + sha256_text("selected image")
  for
    args in [
      [
        "--seal-oracle", digest, "--oracle-profile", "test-reports/oracle/profile.json",
      ],
      [
        "--oracle-profile", "test-reports/oracle/profile.json", "--seal-oracle",
        digest,
      ],
    ] {
    let selected = parse_oracle_options(args[:])
    assert_eq(selected.profile_path, "test-reports/oracle/profile.json")
    assert_eq(selected.seal_digest, Some(digest))
    assert_true(selected.arguments.is_empty())
  }
  let selected = parse_oracle_options(
    [
      "--manifest", "release.json", "--oracle-profile", "profile.json", "--suite",
      "differential",
    ][:],
  )
  assert_eq(selected.arguments, [
    "--manifest", "release.json", "--suite", "differential",
  ])
  assert_eq(selected.profile_path, "profile.json")
}

///|
test "oracle CLI options reject missing duplicate and conflicting arguments" {
  let digest = "sha256:" + sha256_text("selected image")
  for
    args in [
      ["--oracle-profile"],
      ["--oracle-profile", ""],
      ["--oracle-profile", "--suite", "oracle"],
      ["--oracle-profile", "first", "--oracle-profile", "second"],
      ["--seal-oracle", "mutable:tag"],
      ["--seal-oracle", digest, "--seal-oracle", digest],
      ["--seal-oracle", digest, "--suite", "oracle"],
    ] {
    try parse_oracle_options(args[:]) catch {
      _ => ()
    } noraise {
      _ => fail("invalid oracle options must fail before execution")
    }
  }
}

///|
async test "staged oracle sealing preserves reviewed inputs and verified identity" {
  let root = @fs.tmpdir(prefix="mooncmd-oracle-override-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let reviewed_dir = root + "/reviewed"
  let staged_dir = root + "/staged"
  @fs.mkdir(reviewed_dir)
  @fs.mkdir(staged_dir)
  let recipe = "ARG FIXTURE_VERSION=1.0\nARG FIXTURE_SHA256=" +
    sha256_text("source") +
    "\n"
  let inventory_recipe = "fixture version inventory recipe\n"
  let reviewed : OracleProfile = {
    schema: 1,
    id: "pinned-oracle-v1",
    profile_version: 1,
    image: "fixture:reviewed",
    base_image_digest: "sha256:" + sha256_text("base"),
    image_digest: "",
    versions: "",
    versions_sha256: "",
    dockerfile_sha256: sha256_text(recipe),
    versions_script_sha256: sha256_text(inventory_recipe),
    sources: [],
  }
  let original = canonical_json(ToJson::to_json(reviewed)) + "\n"
  for directory in [reviewed_dir, staged_dir] {
    @fs.write_file(directory + "/profile.json", original)
    @fs.write_file(directory + "/Dockerfile", recipe)
    @fs.write_file(directory + "/versions.sh", inventory_recipe)
  }
  let staged_path = staged_dir + "/profile.json"
  let digest = "sha256:" + sha256_text("immutable image")
  let inventory = "fixture 1.0\n"
  let calls : Array[Array[String]] = []
  let execute : async (Array[String]) -> RunResult = args => {
    calls.push(args.copy())
    {
      status: 0,
      stdout: @utf8.encode(
        if args[0] == "image" {
          digest + "\n"
        } else {
          inventory
        },
      ),
      stderr: b"",
    }
  }
  seal_oracle_profile_with(
    staged_path,
    digest,
    execute,
    expected_profile=reviewed,
  )
  assert_eq(@fs.read_file(reviewed_dir + "/profile.json").text(), original)
  assert_eq(@fs.read_file(reviewed_dir + "/Dockerfile").text(), recipe)
  assert_eq(
    @fs.read_file(reviewed_dir + "/versions.sh").text(),
    inventory_recipe,
  )
  let sealed_profile = read_oracle_profile(staged_path)
  assert_eq(sealed_profile.image_digest, digest)
  assert_eq(sealed_profile.versions_sha256, sha256_text(inventory))
  assert_eq(sealed_profile.sources.length(), 1)
  let identity = verify_oracle_image_with(
    reviewed.image,
    staged_path,
    execute,
    expected_profile=reviewed,
    required_profile_ids=["pinned-oracle-v1"],
  )
  assert_eq(identity.profile_id, reviewed.id)
  assert_eq(identity.digest, digest)
  assert_eq(identity.versions, inventory)
  assert_eq(calls.length(), 4)
  assert_eq(calls[0], ["image", "inspect", "--format={{.Id}}", digest])
  assert_eq(calls[1], ["run", "--rm", digest, "/usr/local/bin/versions.sh"])
  assert_eq(calls[2], ["image", "inspect", "--format={{.Id}}", reviewed.image])
  assert_eq(calls[3], calls[1])

  // Reusing the reviewed ID cannot authorize a different recipe or inventory.
  for
    unrelated in [
      { ..sealed_profile, id: "unrelated-profile", },
      { ..sealed_profile, profile_version: 2, },
      { ..sealed_profile, image: "unrelated:tag", },
      {
        ..sealed_profile,
        base_image_digest: "sha256:" + sha256_text("different base"),
      },
      { ..sealed_profile, dockerfile_sha256: sha256_text("different recipe"), },
      {
        ..sealed_profile,
        versions_script_sha256: sha256_text("different inventory recipe"),
      },
      {
        ..sealed_profile,
        sources: [{ ..sealed_profile.sources[0], version: "2.0", }],
      },
    ] {
    @fs.write_file(staged_path, canonical_json(ToJson::to_json(unrelated)))
    try
      verify_oracle_image_with(
        unrelated.image,
        staged_path,
        execute,
        expected_profile=reviewed,
        required_profile_ids=["pinned-oracle-v1"],
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("unrelated profiles must fail before launching Docker")
    }
    assert_eq(calls.length(), 4)
  }
  @fs.write_file(staged_path, canonical_json(ToJson::to_json(sealed_profile)))
  try
    verify_oracle_image_with(
      sealed_profile.image,
      staged_path,
      execute,
      expected_profile=reviewed,
      required_profile_ids=["another-registry-profile"],
    )
  catch {
    error =>
      assert_true(error.to_string().contains("selected registry bindings"))
  } noraise {
    _ => fail("registry profile mismatch must fail")
  }
  assert_eq(calls.length(), 4)
  assert_eq(@fs.read_file(reviewed_dir + "/profile.json").text(), original)
  assert_false(
    oracle_profile_binding_errors(
      {
        ..sealed_profile,
        image_digest: "sha256:" + sha256_text("different image"),
      },
      sealed_profile,
    ).is_empty(),
  )
}
