///|
/// Collect only public registry responses. This operation never publishes and
/// requires a fresh ignored directory so subsequent evidence keeps a clean HEAD.
async fn prepare_acceptance_evidence(args : ArrayView[String]) -> Unit {
  guard args.length() >= 1 && args.length() % 2 == 1 else {
    fail(
      "expected --prepare-freeze-evidence DIRECTORY [--smoke-report PATH] [--semantic-report PATH]",
    )
  }
  let directory = args[0]
  let smoke : Array[String] = []
  let semantic : Array[String] = []
  for index = 1; index < args.length(); index = index + 2 {
    let path = evidence_relative_path(args[index + 1], "acceptance report")
    match args[index] {
      "--smoke-report" => smoke.push(path)
      "--semantic-report" => semantic.push(path)
      _ => fail("unknown acceptance evidence option: " + args[index])
    }
  }
  guard !smoke.is_empty() && !semantic.is_empty() else {
    fail("both smoke and semantic report paths are required")
  }
  let root = workspace_root()
  let state = @testkit.run("git", [
    "-C", root, "status", "--porcelain=v1", "--untracked-files=normal",
  ])
  guard state.status == 0 && state.stdout == b"" else {
    fail("acceptance evidence requires a clean committed checkout")
  }
  let revision = @testkit.run("git", ["-C", root, "rev-parse", "HEAD"])
  guard revision.status == 0 else { fail("cannot resolve acceptance revision") }
  let candidate_path = root + "/tests/release_runner/current/candidate.json"
  let (candidate, _) = candidate_for_freeze(
    root,
    candidate_path,
    registry_path=root + "/tests/registry/registry.json",
  )
  guard candidate.core_version is Some(core_version) else {
    fail("candidate does not identify cli/core")
  }
  guard !@fs.exists(directory) else {
    fail("acceptance evidence directory already exists: " + directory)
  }
  @fs.mkdir(directory, recursive=true)
  @fs.mkdir(directory + "/registry")
  @fs.mkdir(directory + "/verified-registry")
  let expected = [("cli/core", core_version)]
  expected.append(
    candidate.commands.map(row => (row.package_name, row.version)),
  )
  let receipts : Array[Json] = []
  for (name, version) in expected {
    let (url, _) = freeze_registry_urls(name, version)
    let (status, body) = fetch_official_registry(url)
    guard status == 200 else {
      fail("registry receipt request failed: " + name + "@" + version)
    }
    let response_text = @utf8.decode(body)
    ignore(live_registry_checksum(@json.parse(response_text), name, version))
    let filename = "registry/" + name.replace_all(old="/", new="-") + ".json"
    write_immutable(directory + "/" + filename, body)
    let verified = verify_live_registry_release(name, version, response_text)
    let verified_bytes = @utf8.encode(@testkit.canonical_json(verified) + "\n")
    write_immutable(
      directory +
      "/verified-registry/" +
      @testkit.sha256_bytes(verified_bytes) +
      ".json",
      verified_bytes,
    )
    receipts.push({
      "package_name": Json(name),
      "version": Json(version),
      "status": Json(status),
      "response_file": Json(filename),
      "response_sha256": Json(@testkit.sha256_bytes(body)),
    })
  }
  let evidence : Json = {
    "schema": 1,
    "candidate_hash": Json(@testkit.manifest_digest(candidate_path)),
    "git_revision": Json(@utf8.decode(revision.stdout).trim().to_owned()),
    "registry": Json::array(receipts),
    "smoke_report_dirs": ToJson::to_json(smoke),
    "semantic_report_dirs": ToJson::to_json(semantic),
  }
  write_immutable(
    directory + "/evidence.json",
    @utf8.encode(@testkit.canonical_json(evidence) + "\n"),
  )
  let final_state = @testkit.run("git", [
    "-C", root, "status", "--porcelain=v1", "--untracked-files=normal",
  ])
  guard final_state.status == 0 && final_state.stdout == b"" else {
    fail("acceptance outputs must be ignored; checkout became dirty")
  }
  println(
    "Verified exact public registry receipts: " + expected.length().to_string(),
  )
}
