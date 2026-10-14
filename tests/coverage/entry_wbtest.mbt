///|
async test "release selection uses explicit case IDs and checks unknown IDs" {
  let root = @fs.tmpdir(prefix="mooncmd-coverage-selection-")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let corpus : Json = {
    "schema": 2,
    "cases": [
      {
        "id": "selected",
        "aliases": ["legacy-selected"],
        "command": "echo",
        "args": [],
        "files": [],
        "environment": {},
        "expected_status": 0,
        "normalizations": [],
      },
      {
        "id": "excluded",
        "command": "echo",
        "args": [],
        "files": [],
        "environment": {},
        "expected_status": 0,
        "normalizations": [],
      },
    ],
  }
  @fs.write_file(root + "/corpus.json", corpus.stringify())
  let manifest : Json = {
    "base_manifest": "corpus.json",
    "case_ids": ["legacy-selected"],
    "extra_cases": [],
  }
  @fs.write_file(root + "/manifest.json", manifest.stringify())
  assert_eq(
    selected_manifest_cases(root + "/manifest.json").map(item => item.id),
    ["selected"],
  )
  let extra = {
    ..@testkit.load_cases(root + "/corpus.json")[0],
    id: "extra",
    aliases: None,
  }
  @fs.write_file(
    root + "/manifest.json",
    @testkit.canonical_json({
      "base_manifest": "corpus.json",
      "case_ids": [],
      "extra_cases": [ToJson::to_json(extra)],
    }),
  )
  assert_eq(
    selected_manifest_cases(root + "/manifest.json").map(item => item.id),
    ["selected", "excluded", "extra"],
  )
  @fs.write_file(
    root + "/manifest.json",
    @testkit.canonical_json({
      "base_manifest": "corpus.json",
      "case_ids": ["excluded", "legacy-selected", "extra", "selected"],
      "extra_cases": [ToJson::to_json(extra)],
    }),
  )
  assert_eq(
    selected_manifest_cases(root + "/manifest.json").map(item => item.id),
    ["extra", "excluded", "selected"],
  )
  @fs.write_file(
    root + "/manifest.json",
    @testkit.canonical_json({
      "base_manifest": "corpus.json",
      "case_ids": ["legacy-selected"],
      "extra_cases": [ToJson::to_json(extra)],
    }),
  )
  assert_eq(
    selected_manifest_cases(root + "/manifest.json").map(item => item.id),
    ["extra", "selected"],
  )
  @fs.write_file(
    root + "/manifest.json",
    "{\"base_manifest\":\"corpus.json\",\"case_ids\":[\"absent\"]}",
  )
  let rejected = selected_manifest_cases(root + "/manifest.json") catch {
    _ => []
  }
  assert_true(rejected.is_empty())
}

///|
test "audit CLI rejects missing, unknown and duplicate singleton options" {
  let absent = parse_arguments(["--base", "HEAD"]) catch { _ => Map([]) }
  assert_true(absent.is_empty())
  let duplicate = parse_arguments([
    "--base", "HEAD", "--base", "HEAD", "--head", "HEAD", "--declaration", "change.json",
    "--run-metadata", "run.json",
  ]) catch {
    _ => Map([])
  }
  assert_true(duplicate.is_empty())
  let unknown = parse_arguments(["--unknown", "value"]) catch { _ => Map([]) }
  assert_true(unknown.is_empty())
  let valid = parse_arguments([
    "--base", "HEAD~1", "--head", "HEAD", "--declaration", "change.json", "--run-metadata",
    "native/run-metadata.json", "--run-metadata", "wasm/run-metadata.json",
  ])
  assert_eq(valid["--run-metadata"].length(), 2)
}

///|
test "mutable or unsealed oracle profiles cannot authorize differential evidence" {
  let versions = "coreutils 9.11"
  let metadata = {
    ..audit_metadata("oracle"),
    oracle_profile_id: "pinned-v1",
    oracle_image_digest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    oracle_versions_hash: @testkit.sha256_text(versions),
  }
  let profile : Json = {
    "schema": 1,
    "id": "pinned-v1",
    "profile_version": 1,
    "image": "oracle:test",
    "image_digest": Json(metadata.oracle_image_digest),
    "versions_sha256": Json(metadata.oracle_versions_hash),
    "versions": Json(versions),
    "dockerfile_sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "versions_script_sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "base_image_digest": "sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    "sources": [
      {
        "project": "coreutils",
        "version": "9.11",
        "sha256": "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",
      },
    ],
  }
  assert_true(profile_matches(profile, metadata))
  assert_true(
    !profile_matches(profile, {
      ..metadata,
      oracle_image_digest: "mooncmd-oracle:latest",
    }),
  )
  assert_true(!profile_matches({ "id": "pinned-v1", "sources": [] }, metadata))
  let profile : @testkit.OracleProfile = @json.from_json(profile)
  assert_false(
    profile_matches(
      ToJson::to_json({ ..profile, versions: "modified inventory", }),
      metadata,
    ),
  )
}
