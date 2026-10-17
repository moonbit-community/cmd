///|
async fn ci_audit(
  context : CiContext,
  evidence_root : String,
  output : String,
) -> Bool {
  guard @env.get_env_var("CMD_MATRIX_RESULT") == Some("success") else {
    fail("all three platform jobs must succeed before the CI coverage audit")
  }
  let (metadata_paths, corpora, profiles, frozen) = ci_verified_reports(
    context, evidence_root,
  )
  let paths = if context.base == "" {
    []
  } else {
    git_changed_paths(context.base, context.head)
  }
  let regression_only = context.base == ""
  let documentation_only = !paths.is_empty() && paths.all(ci_documentation_path)
  if regression_only || documentation_only {
    let reason = if regression_only {
      "scheduled/manual regression validation; no change range was claimed"
    } else {
      "every changed path is in the documentation-only allowlist"
    }
    let result : Json = {
      "schema": 1,
      "status": "not-applicable",
      "reason": Json(reason),
      "context": ToJson::to_json(context),
      "changed_paths": Json(paths),
      "verified_metadata": Json(metadata_paths),
    }
    @fs.write_file(
      output + ".json",
      @testkit.canonical_json(result) + "\n",
      create_mode=@fs.CreateNew,
    )
    @fs.write_file(
      output,
      "# CI coverage audit\n\nStatus: not-applicable\n\n" + reason + "\n",
      create_mode=@fs.CreateNew,
    )
    return true
  }
  guard !paths.is_empty() else {
    fail("a change event must have a nonempty audited range")
  }
  let declaration_path = "tests/coverage/ci-change.json"
  let impact = ci_impact(@json.parse(@fs.read_file(declaration_path).text()))
  let registry = @registry.load("tests/registry/registry.json")
  let errors = ci_scope_errors(paths, impact, registry)
  guard errors.is_empty() else { fail(errors.join("\n")) }
  let reports = metadata_paths.map(path => {
    @path.Path(path)
    .dirname()
    .join(Path("summary.jsonl"))
    .normalize()
    .to_string()
  })
  let declaration = ci_declaration(impact, registry, reports)
  let report = audit_declared(
    {
      base: context.base,
      head: context.head,
      declaration_path,
      run_metadata_paths: metadata_paths,
      registry_path: "tests/registry/registry.json",
      case_corpus_paths: corpora,
      manifest_paths: [
        "tests/fixtures/runner/cases.json", "tests/registry/registry.json",
      ],
      oracle_profile_paths: profiles,
      report_path: Some(output),
    },
    declaration,
    platforms=["linux", "macos", "windows"],
    ci=true,
    frozen~,
  )
  @fs.write_file(output, report_text(report), create_mode=@fs.CreateNew)
  @fs.write_file(
    output + ".json",
    @testkit.canonical_json(report.to_json()) + "\n",
    create_mode=@fs.CreateNew,
  )
  @fs.write_file(
    output + ".context.json",
    @testkit.canonical_json(ToJson::to_json(context)) + "\n",
    create_mode=@fs.CreateNew,
  )
  report.status == "passed"
}

///|
async fn run_ci(args : Array[String]) -> Unit {
  let output = match args[:] {
    ["audit", _, output] => Some(output)
    _ => None
  }
  if output is Some(output) {
    @fs.mkdir(
      @path.Path(output).dirname().to_string(),
      recursive=true,
      allow_exist=true,
    )
  }
  let result = try {
    let context = ci_context()
    match args[:] {
      ["requirements"] => {
        ci_requirements(context)
        true
      }
      ["stamp", directory] => {
        ci_stamp(context, directory)
        true
      }
      ["audit", root, output] => ci_audit(context, root, output)
      _ =>
        fail(
          "Usage: ci.mbtx requirements | stamp REPORT_ROOT | audit DOWNLOADED_ROOT REPORT.md",
        )
    }
  } catch {
    error => {
      if output is Some(output) {
        let failure : Json = {
          "schema": 1,
          "status": "failed",
          "stage": "infrastructure",
          "detail": Json(error.to_string()),
          "head": Json(@env.get_env_var("GITHUB_SHA").unwrap_or("")),
          "run_id": Json(@env.get_env_var("GITHUB_RUN_ID").unwrap_or("")),
        }
        @fs.write_file(
          output + ".failure.json",
          @testkit.canonical_json(failure) + "\n",
          create_mode=@fs.CreateNew,
        ) catch {
          save_error =>
            @stdio.stderr.write(
              "Cannot retain CI failure report: " +
              save_error.to_string() +
              "\n",
            )
        }
      }
      @stdio.stderr.write(
        "CI coverage infrastructure: " + error.to_string() + "\n",
      )
      @sys.exit(2)
      return
    }
  }
  if !result {
    @sys.exit(1)
  }
}
