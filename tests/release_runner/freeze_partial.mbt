///|
/// A partial publication binds the predecessor at the same committed revision
/// as the candidate. These hashes identify the whole previous frozen bundle;
/// its original provenance is replayed recursively, never replaced with trust
/// in locally recomputed hashes.
priv struct FrozenPredecessor {
  manifest_path : String
  manifest_sha256 : String
  corpus_sha256 : String
  registry_sha256 : String
  provenance_sha256 : String
} derive(FromJson, ToJson)

///|
priv struct FrozenSnapshot {
  manifest : Bytes
  corpus : Bytes
  registry : Bytes
  provenance_bytes : Bytes
  provenance : FrozenProvenance
  archives : Map[String, Bytes]
}

///|
async fn read_frozen_snapshot_with(
  path : String,
  read_source : async (String) -> Bytes,
) -> FrozenSnapshot {
  let manifest = read_source(path)
  let corpus = read_source(path + ".cases.json")
  let registry = read_source(path + ".registry.json")
  let provenance_bytes = read_source(path + ".provenance.json")
  let provenance : FrozenProvenance = @json.from_json(
    @json.parse(@utf8.decode(provenance_bytes)),
  )
  let archives : Map[String, Bytes] = Map([])
  for source in provenance.sources {
    guard sha256_identity(source.sha256) else {
      fail("frozen source archive has invalid checksum")
    }
    archives[source.sha256] = read_source(
      path + ".sources/" + source.sha256 + ".json",
    )
  }
  { manifest, corpus, registry, provenance_bytes, provenance, archives, }
}

///|
fn snapshot_manifest(snapshot : FrozenSnapshot) -> ReleaseManifest raise {
  @json.from_json(@json.parse(@utf8.decode(snapshot.manifest)))
}

///|
fn snapshot_case_list(snapshot : FrozenSnapshot) -> Array[ReleaseCase] raise {
  guard @json.parse(@utf8.decode(snapshot.corpus)) is { "cases": cases, .. } else {
    fail("frozen predecessor has no resolved case corpus")
  }
  @json.from_json(cases)
}

///|
fn predecessor_binding(snapshot : FrozenSnapshot) -> FrozenPredecessor {
  {
    manifest_path: "tests/release_runner/current/published.json",
    manifest_sha256: @testkit.sha256_bytes(snapshot.manifest),
    corpus_sha256: @testkit.sha256_bytes(snapshot.corpus),
    registry_sha256: @testkit.sha256_bytes(snapshot.registry),
    provenance_sha256: @testkit.sha256_bytes(snapshot.provenance_bytes),
  }
}

///|
fn predecessor_matches(
  expected : FrozenPredecessor,
  snapshot : FrozenSnapshot,
) -> Bool {
  let actual = predecessor_binding(snapshot)
  expected.manifest_path == actual.manifest_path &&
  expected.manifest_sha256 == actual.manifest_sha256 &&
  expected.corpus_sha256 == actual.corpus_sha256 &&
  expected.registry_sha256 == actual.registry_sha256 &&
  expected.provenance_sha256 == actual.provenance_sha256
}

///|
async fn verified_predecessor(
  root : String,
  revision : String,
  expected : FrozenPredecessor,
  ancestors : Array[String],
) -> FrozenSnapshot {
  guard expected.manifest_path == "tests/release_runner/current/published.json" else {
    fail(
      "partial publication predecessor must be the committed current snapshot",
    )
  }
  let identity = revision + ":" + expected.manifest_path
  guard !ancestors.contains(identity) && ancestors.length() < 128 else {
    fail("partial publication predecessor cycle or excessive depth")
  }
  let snapshot = read_frozen_snapshot_with(expected.manifest_path, path => {
    snapshot_source(root, revision, path)
  })
  guard predecessor_matches(expected, snapshot) else {
    fail("partial publication predecessor differs from committed frozen bytes")
  }
  validate_frozen_snapshot_contents(
    root,
    expected.manifest_path,
    snapshot,
    ancestors + [identity],
  )
  snapshot
}

///|
/// Omit the new optional operation field when writing a published inventory.
/// This also preserves exact replay of publications committed before scopes
/// existed, irrespective of the JSON derive's treatment of absent options.
fn publication_json(manifest : ReleaseManifest) -> Json {
  let value = ToJson::to_json(manifest)
  if value is Object(fields) && manifest.release_scope is None {
    fields.remove("release_scope")
  }
  value
}
