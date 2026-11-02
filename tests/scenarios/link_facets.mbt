///|
async fn link_dereference_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  @fs.mkdir(work + "/dir")
  @fs.write_file(work + "/dir/a", "retained\n")
  @fs.symlink(target="dir", work + "/link")
  @fs.symlink(target="absent", work + "/broken")
  @fs.symlink(target="absent", work + "/dir/missing")
  assert_false(@fs.exists(work + "/absent"))
  assert_false(@fs.exists(work + "/dir/absent"))
  for
    (label, args, status, output, failed_path) in [
      ("operand-H", ["-H", "broken", "dir/a"], 2, "dir/a\n", "broken"),
      ("operand-L", ["-L", "broken"], 2, "", "broken"),
      ("child-L", ["-LF", "dir"], 1, "a\nmissing@\n", "dir/missing"),
      ("child-H", ["-HF", "link"], 0, "a\nmissing@\n", ""),
      ("literal", ["-PF", "broken"], 0, "broken@\n", ""),
    ] {
    let result = scenario_run(work, root, "ls", args, cwd=work)
    let error = @harness.scenario_text(result.stderr)
    let diagnostic = if failed_path == "" {
      error == ""
    } else {
      error.has_prefix("ls: cannot access '" + failed_path + "': ") &&
      error.has_suffix("\n") &&
      error.contains("No such file") &&
      error.split("\n").count() == 2
    }
    let actual : Json = {
      "status": result.status,
      "stdout": @harness.scenario_text(result.stdout),
      "diagnostic": diagnostic,
      "links_preserved": @fs.kind(work + "/link", follow_symlink=false) ==
      @fs.SymLink &&
      @fs.kind(work + "/broken", follow_symlink=false) == @fs.SymLink &&
      @fs.kind(work + "/dir/missing", follow_symlink=false) == @fs.SymLink,
      "source": @fs.read_file(work + "/dir/a").text(),
    }
    let expected : Json = {
      "status": status,
      "stdout": output,
      "diagnostic": true,
      "links_preserved": true,
      "source": "retained\n",
    }
    assert_eq(actual, expected)
    if proof is Some(proof) {
      proof.observe_equal("ls/" + label, "ls", actual, expected)
    }
  }
}
