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
    let paths = git_changed_paths(context.base, context.head)
    let history_errors = ci_report_history_errors(context.base, context.head)
    guard history_errors.is_empty() else { fail(history_errors.join("\n")) }
    paths
  }
  let shadow = ci_scope_preflight(context)
  let root = ci_git(["rev-parse", "--show-toplevel"])
  let snapshot = @scope.read_tree(root, context.head)
  let full = @scope.full_regression_requirements(
    snapshot,
    @scope.capture_graph(snapshot),
    context.head,
  )
  let declaration_path = "tests/coverage/ci-change.json"
  let registry = @registry.load("tests/registry/registry.json")
  let mapping_errors = match shadow {
    Some(intent) => ci_scope_mapping_errors(intent, registry)
    None => []
  }
  guard mapping_errors.is_empty() else { fail(mapping_errors.join("\n")) }
  let impact = ci_full_shadow_impact(full, shadow, registry)
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
      base: if context.base == "" {
        context.head
      } else {
        context.base
      },
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
    scope=shadow,
    full_scope=Some(full),
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
  let comparison : Json = {
    "schema": 1,
    "context": ToJson::to_json(context),
    "execution_mode": "full",
    "status": report.status,
    "change_range_classification": if context.base == "" {
      "regression-only/full"
    } else {
      match shadow {
        Some(intent) => intent.selection.mode
        None => "invalid"
      }
    },
    "shadow_scope_fingerprint": ci_scope_fingerprint(shadow),
    "full_behavior_count": full.selection.behaviors.length(),
    "full_requirement_count": full.selection.requirements.length(),
    "shadow_requirement_count": match shadow {
      Some(intent) => intent.selection.requirements.length()
      None => 0
    },
    "observed_run_ids": report.run_ids,
    "findings": report.findings,
    "unresolved_before": context.unresolved_base.unwrap_or(""),
  }
  @fs.write_file(
    output + ".scope-shadow.json",
    @testkit.canonical_json(comparison) + "\n",
    create_mode=CreateNew,
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
