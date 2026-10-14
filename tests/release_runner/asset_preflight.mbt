///|
/// Resolve missing exact assets before freezing execution inputs. Help is only
/// an availability warmup; its output never counts as case semantic evidence.
async fn prepare_release_assets(
  rows : Array[ReleaseCommand],
  moonx : String,
  timeout_ms : Int32,
  directory : String,
  candidate_executor~ : async (CandidateInvocation) -> @testkit.TimedRun = execute_candidate_process,
  asset_digest~ : async (ArrayView[String]) -> String = @testkit.moonx_artifact_digest,
) -> Unit {
  let rows = rows.copy()
  rows.sort_by((left, right) => left.name.lexical_compare(right.name))
  for row in rows {
    let coordinate = row.package_name + "@" + row.version
    if asset_digest([coordinate]) != "" {
      continue
    }
    let evidence = directory + "/asset-preflight/" + row.name
    guard !@fs.exists(evidence) else {
      fail("asset preflight evidence already exists: " + evidence)
    }
    @fs.mkdir(evidence, recursive=true)
    let invocation : CandidateInvocation = {
      program: moonx,
      args: [coordinate, "--", "--help"],
      timeout_ms,
      stdin: b"",
      cwd: @fs.realpath(evidence),
      environment: controlled_environment(Map([])),
    }
    let observed = candidate_executor(invocation) catch {
      error =>
        fail(
          "MoonX asset preflight could not start: " +
          error.to_string() +
          "; artifacts: " +
          evidence,
        )
    }
    @fs.write_file(evidence + "/stdout", observed.output.stdout)
    @fs.write_file(evidence + "/stderr", observed.output.stderr)
    let receipt : Json = {
      "coordinate": Json(coordinate),
      "verification": "availability",
      "status": Json(observed.output.status),
      "timed_out": Json(observed.timed_out),
      "cleanup_error": ToJson::to_json(observed.cleanup_error),
    }
    @fs.write_file(
      evidence + "/result.json",
      @testkit.canonical_json(receipt) + "\n",
    )
    guard !observed.timed_out &&
      observed.cleanup_error is None &&
      observed.output.status == 0 else {
      fail(
        "MoonX asset preflight did not complete successfully: " +
        coordinate +
        "; artifacts: " +
        evidence,
      )
    }
    guard asset_digest([coordinate]) != "" else {
      fail(
        "MoonX asset preflight did not expose exact cached Wasm bytes: " +
        coordinate +
        "; artifacts: " +
        evidence,
      )
    }
  }
}
