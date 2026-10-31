///|
pub(all) struct CaseReport {
  id : String
  command : String
  result : String
  verification : String
  stage : String
  detail : String
  platform : String
  backend : String
  source_version : String
  duration_ms : Int64
  observations : Array[String]
  missing_observations : Array[String]
  evidence : String?
} derive(ToJson, Debug)

///|
pub fn CaseReport::semantic_pass(self : CaseReport) -> Bool {
  self.result == "pass" &&
  (self.verification == "contract" || self.verification == "differential") &&
  self.missing_observations.is_empty()
}

///|
/// Emit completed results immediately so cancelled jobs retain useful logs.
pub fn append_report(reports : Array[CaseReport], report : CaseReport) -> Unit {
  reports.push(report)
  println(
    "\{report.result} \{report.verification} \{report.id} \{report.duration_ms}ms \{report.detail}",
  )
}

///|
pub async fn write_reports(
  directory : String,
  reports : ArrayView[CaseReport],
  case_definitions_sha256? : String,
  scenario_proofs_sha256? : String,
) -> Unit {
  guard !reports.is_empty() else { fail("required suite produced no results") }
  @fs.mkdir(directory, recursive=true, allow_exist=true)
  guard !@fs.exists(directory + "/summary.jsonl") else {
    fail("report already exists: " + directory)
  }
  let results_text = reports
    .map(item => ToJson::to_json(item).stringify())
    .join("\n") +
    "\n"
  @fs.write_file(directory + "/summary.jsonl", results_text)
  let summary : Json = {
    "schema": 2,
    "platform": host_platform(),
    "revision": @env.get_env_var("GITHUB_SHA").unwrap_or("local"),
    "mode": if published_mode() {
      "moonx"
    } else {
      "wasm"
    },
    "commands": published_commands,
    "completed_at_ms": @async.now(),
    "results_sha256": sha256_bytes(@utf8.encode(results_text)),
    "passed": reports.filter(row => row.result == "pass").length(),
    "failed": reports
    .filter(row => row.result == "fail" || row.result == "infra")
    .length(),
    "skipped": reports.filter(row => row.result == "skip").length(),
  }
  if case_definitions_sha256 is Some(hash) && summary is Object(fields) {
    fields["case_definitions_sha256"] = Json(hash)
  }
  if scenario_proofs_sha256 is Some(hash) && summary is Object(fields) {
    fields["scenario_proofs_sha256"] = Json(hash)
  }
  @fs.write_file(directory + "/run.json", summary.stringify(indent=2) + "\n")
  let lines = StringBuilder()
  lines.write(
    "| Case | Result | Kind | ms | Detail |\n| --- | --- | --- | --- | --- |\n",
  )
  for row in reports {
    let detail = row.detail
      .replace_all(old="|", new="\\|")
      .replace_all(old="\n", new="<br>")
    lines.write(
      "| \{row.id} | \{row.result} | \{row.verification} | \{row.duration_ms} | \{detail} |\n",
    )
  }
  @fs.write_file(directory + "/summary.md", lines.to_string())
}

///|
pub fn contract_errors(fixture : Case) -> Array[String] {
  let errors : Array[String] = []
  if fixture.comparison is Some(comparison) &&
    ![
      "contract", "boundary", "differential", "exact", "normalized", "scenario",
      "oracle-scenario", "metadata", "compat", "policy", "stress",
    ].contains(comparison) {
    errors.push("unknown comparison: " + comparison)
  }
  if fixture.expected_rejection is Some(reason) && reason.trim().is_empty() {
    errors.push("rejection reason must be nonempty")
  }
  if fixture.comparison == Some("boundary") &&
    fixture.expected_rejection is None {
    errors.push("boundary comparison requires an explicit rejection")
  }
  if fixture.host_platforms is Some(platforms) {
    if platforms.is_empty() {
      errors.push("host_platforms must select at least one platform")
    }
    let seen : Set[String] = Set([])
    for platform in platforms {
      if !["linux", "macos", "windows", "posix"].contains(platform) {
        errors.push("unknown host platform: " + platform)
      }
      if seen.contains(platform) {
        errors.push("duplicate host platform: " + platform)
      }
      seen.add(platform)
    }
  }
  for
    (field, fragment) in [
      ("stdout", fixture.expected_stdout_contains),
      ("stderr", fixture.expected_stderr_contains),
    ] {
    if fragment == Some("") {
      errors.push(
        field +
        " contains assertion must be nonempty; use exact text for empty output",
      )
    }
  }
  for
    (field, fragments) in [
      ("stdout", fixture.expected_stdout_contains_all),
      ("stderr", fixture.expected_stderr_contains_all),
    ] {
    if fragments is Some(fragments) &&
      (fragments.is_empty() || fragments.contains("")) {
      errors.push(field + " contains-all assertion needs nonempty fragments")
    }
  }
  if fixture.forbidden_stderr.unwrap_or([]).contains("") {
    errors.push("forbidden stderr fragments must be nonempty")
  }
  if fixture.cwd is Some(cwd) && !safe_relative_path(cwd) {
    errors.push("unsafe case cwd")
  }
  if fixture.stdout_order is Some(order) && order != "lines" {
    errors.push("unknown stdout_order")
  }
  for file in fixture.expected_files.unwrap_or([]) {
    if !safe_relative_path(file.path) {
      errors.push("unsafe expected file path")
    }
    if file.same_identity_as is Some(path) && !safe_relative_path(path) {
      errors.push("unsafe identity reference")
    }
    if file.same_mtime_as is Some(path) && !safe_relative_path(path) {
      errors.push("unsafe timestamp reference")
    }
    for reference in [file.different_identity_as, file.same_mode_as] {
      if reference is Some(path) && !safe_relative_path(path) {
        errors.push("unsafe metadata reference")
      }
    }
    if file.mode_mask is Some(mask) &&
      (!(mask > 0 && mask <= 0o7777) || file.mode is None) {
      errors.push("mode mask requires explicit mode and valid nonzero bits")
    }
    if file.mode is Some(mode) {
      if mode < 0 || mode > 0o7777 {
        errors.push(
          "expected mode must contain only permission and special bits",
        )
      }
      if file.mode_mask is Some(mask) && (mode & mask) != mode {
        errors.push("expected mode contains bits outside mode mask")
      }
    }
    if file.unchanged == Some(false) {
      errors.push("unchanged expectation must be true")
    }
    if file.exists == Some(false) &&
      (
        file.kind is Some(_) ||
        file.content_text is Some(_) ||
        file.content_hex is Some(_) ||
        file.mode is Some(_) ||
        file.target is Some(_) ||
        file.same_identity_as is Some(_) ||
        file.unchanged is Some(_) ||
        file.mtime is Some(_) ||
        file.atime is Some(_) ||
        file.same_mtime_as is Some(_) ||
        file.same_mode_as is Some(_) ||
        file.different_identity_as is Some(_) ||
        file.mode_mask is Some(_)
      ) {
      errors.push(
        "absent file expectation cannot assert ignored metadata or content",
      )
    }
    ignore(input_bytes(file.content_hex, file.content_text, file.path)) catch {
      error => errors.push(error.to_string())
    }
  }
  if fixture.comparison == Some("contract") &&
    fixture.expected_rejection is None {
    for dimension in fixture.observe.unwrap_or([]) {
      let asserted = fixture.expected_files
        .unwrap_or([])
        .any(file => {
          match dimension {
            "content" =>
              file.content_text is Some(_) || file.content_hex is Some(_)
            "type" => file.kind is Some(_) || file.exists is Some(_)
            "mode" =>
              file.mode is Some(_) ||
              file.same_mode_as is Some(_) ||
              file.unchanged == Some(true)
            "identity" =>
              file.same_identity_as is Some(_) ||
              file.different_identity_as is Some(_) ||
              file.unchanged == Some(true)
            "mtime" =>
              file.mtime is Some(_) ||
              file.same_mtime_as is Some(_) ||
              file.unchanged == Some(true)
            "atime" => file.atime is Some(_) || file.unchanged == Some(true)
            "symlink-target" =>
              file.target is Some(_) ||
              file.unchanged == Some(true) ||
              (file.kind is Some(kind) && kind != "symlink")
            _ => false
          }
        })
      if !asserted {
        errors.push("filesystem expectation missing for " + dimension)
      }
    }
  }
  for
    (hex, text, field) in [
      (fixture.stdin_hex, fixture.stdin_text, "stdin"),
      (fixture.expected_stdout_hex, fixture.expected_stdout_text, "stdout"),
      (fixture.expected_stderr_hex, fixture.expected_stderr_text, "stderr"),
    ] {
    ignore(input_bytes(hex, text, field)) catch {
      error => errors.push(error.to_string())
    }
  }
  if fixture.comparison == Some("contract") &&
    fixture.expected_rejection is None {
    if !fixture.observe.unwrap_or([]).is_empty() &&
      fixture.expected_files.unwrap_or([]).is_empty() {
      errors.push(
        "single-command contract has no filesystem expectation; use a scenario or differential case for observe",
      )
    }
    if fixture.expected_stdout_hex is None &&
      fixture.expected_stdout_text is None &&
      fixture.expected_stdout_json is None &&
      fixture.expected_stdout_contains is None &&
      fixture.expected_stdout_contains_all.unwrap_or([]).is_empty() {
      errors.push("contract requires a stdout assertion")
    }
    if fixture.expected_stderr_hex is None &&
      fixture.expected_stderr_text is None &&
      fixture.expected_stderr_contains is None &&
      fixture.expected_stderr_contains_all.unwrap_or([]).is_empty() {
      errors.push("contract requires a stderr assertion")
    }
    if (
        fixture.expected_stdout_contains is Some(_) ||
        fixture.expected_stderr_contains is Some(_) ||
        !fixture.expected_stdout_contains_all.unwrap_or([]).is_empty() ||
        !fixture.expected_stderr_contains_all.unwrap_or([]).is_empty()
      ) &&
      fixture.diagnostic_reason.unwrap_or("").trim().is_empty() {
      errors.push("partial matching requires diagnostic_reason")
    }
  }
  if fixture.stdout_json_lines is Some(_) &&
    fixture.expected_stdout_json is None {
    errors.push("JSON line framing requires a complete JSON expectation")
  }
  errors
}

///|
pub fn check_contract(
  fixture : Case,
  result : RunResult,
  root : String,
  http_base? : String,
) -> Array[String] {
  let errors = contract_errors(fixture)
  if result.status != fixture.expected_status {
    errors.push(
      "exit status \{result.status}, expected \{fixture.expected_status}",
    )
  }
  for
    (data, hex, text, field) in [
      (
        result.stdout,
        fixture.expected_stdout_hex,
        fixture.expected_stdout_text,
        "stdout",
      ),
      (
        result.stderr,
        fixture.expected_stderr_hex,
        fixture.expected_stderr_text,
        "stderr",
      ),
    ] {
    if hex is Some(_) || text is Some(_) {
      let expected = input_bytes(
        hex,
        text.map(value => expand_text(value, root, http_base?)),
        field,
      ) catch {
        error => {
          errors.push(error.to_string())
          continue
        }
      }
      let actual = normalize_text(data, field, fixture.normalizations, root)
      let expected = normalize_text(
        expected,
        field,
        fixture.normalizations,
        root,
      )
      let same = if field == "stdout" && fixture.stdout_order == Some("lines") {
        unordered_lines_equal(actual, expected)
      } else {
        bytes_equal(actual, expected)
      }
      if !same {
        errors.push(field + " bytes differ")
      }
    }
  }
  if fixture.expected_stdout_contains is Some(value) &&
    !contains_bytes(result.stdout, expand_text(value, root)) {
    errors.push("stdout missing expected fragment")
  }
  if fixture.expected_stderr_contains is Some(value) &&
    !contains_bytes(result.stderr, expand_text(value, root)) {
    errors.push("stderr missing expected fragment")
  }
  for
    (data, fragments, field) in [
      (result.stdout, fixture.expected_stdout_contains_all, "stdout"),
      (result.stderr, fixture.expected_stderr_contains_all, "stderr"),
    ] {
    for fragment in fragments.unwrap_or([]) {
      if !contains_bytes(data, expand_text(fragment, root)) {
        errors.push(field + " missing expected fragment: " + fragment)
      }
    }
  }
  if fixture.expected_stdout_ends_with_newline is Some(expected) &&
    ends_with_newline(result.stdout) != expected {
    errors.push("stdout newline mismatch")
  }
  if fixture.expected_stderr_ends_with_newline is Some(expected) &&
    ends_with_newline(result.stderr) != expected {
    errors.push("stderr newline mismatch")
  }
  for word in fixture.forbidden_stderr.unwrap_or([]) {
    if contains_bytes(result.stderr, word) {
      errors.push("stderr contains forbidden text: " + word)
    }
  }
  errors
}

///|
pub fn unordered_lines_equal(left : Bytes, right : Bytes) -> Bool {
  if ends_with_newline(left) != ends_with_newline(right) {
    return false
  }
  let left = @utf8.decode(left) catch { _ => return false }
  let right = @utf8.decode(right) catch { _ => return false }
  let left = left.split("\n").map(StringView::to_owned).collect()
  let right = right.split("\n").map(StringView::to_owned).collect()
  left.sort()
  right.sort()
  left == right
}

///|
pub fn contract_observations(fixture : Case) -> Array[String] {
  let dimensions = fixture.observe.unwrap_or([]).copy()
  for file in fixture.expected_files.unwrap_or([]) {
    for
      (needed, name) in [
        (true, "type"),
        (file.content_text is Some(_) || file.content_hex is Some(_), "content"),
        (file.mode is Some(_) || file.same_mode_as is Some(_), "mode"),
        (file.target is Some(_), "symlink-target"),
        (
          file.same_identity_as is Some(_) ||
          file.different_identity_as is Some(_),
          "identity",
        ),
        (file.mtime is Some(_) || file.same_mtime_as is Some(_), "mtime"),
        (file.atime is Some(_), "atime"),
      ] {
      if needed && !dimensions.contains(name) {
        dimensions.push(name)
      }
    }
  }
  dimensions
}

///|
fn mode_observation_matches(
  measured : String?,
  expected : Int32,
  mask : Int32?,
) -> Bool {
  let bits = mask.unwrap_or(0o7777)
  guard expected >= 0 &&
    expected <= 0o7777 &&
    bits > 0 &&
    bits <= 0o7777 &&
    (expected & bits) == expected &&
    measured is Some(text) &&
    text.length() >= 1 &&
    text.length() <= 4 &&
    text.iter().all(c => c >= '0' && c <= '7') else {
    return false
  }
  let parsed = @string.parse_int(text, base=8) catch { _ => return false }
  (parsed & bits) == expected
}

///|
pub async fn check_expected_files(
  fixture : Case,
  root : String,
  http_base? : String,
  baseline? : Array[SnapshotEntry],
) -> Array[String] {
  let expected = fixture.expected_files.unwrap_or([])
  if expected.is_empty() {
    return []
  }
  let read_content = expected.any(file => {
    file.content_text is Some(_) ||
    file.content_hex is Some(_) ||
    file.unchanged == Some(true)
  })
  let entries = snapshot(
    root,
    observe=contract_observations(fixture),
    content=read_content,
    preserve_identity=baseline is Some(_),
  )
  let errors : Array[String] = []
  for file in expected {
    let found = entries.iter().find_first(entry => entry.path == file.path)
    if file.exists == Some(false) {
      if found is Some(_) {
        errors.push(file.path + ": unexpectedly exists")
      }
      continue
    }
    guard found is Some(actual) else {
      errors.push(file.path + ": missing")
      continue
    }
    if file.kind is Some(kind) && actual.kind != kind {
      errors.push(file.path + ": type differs")
    }
    if file.content_hex is Some(_) || file.content_text is Some(_) {
      let content = input_bytes(
        file.content_hex,
        file.content_text.map(value => expand_text(value, root, http_base?)),
        file.path,
      )
      if actual.kind != "file" || actual.content != content {
        errors.push(file.path + ": content differs")
      }
    }
    if file.mode is Some(mode) {
      if !mode_observation_matches(
          actual.metadata.get("mode"),
          mode,
          file.mode_mask,
        ) {
        errors.push(file.path + ": mode differs")
      }
    }
    if file.target is Some(target) &&
      actual.metadata.get("symlink-target") != Some(target) {
      errors.push(file.path + ": symlink target differs")
    }
    if file.same_identity_as is Some(reference) {
      let other = entries.iter().find_first(entry => entry.path == reference)
      if other is Some(other) {
        if actual.metadata.get("identity") != other.metadata.get("identity") {
          errors.push(file.path + ": identity differs from " + reference)
        }
      } else {
        errors.push(reference + ": identity reference missing")
      }
    }
    for (dimension, expected) in [("mtime", file.mtime), ("atime", file.atime)] {
      if expected is Some(value) &&
        actual.metadata.get(dimension) != Some(value) {
        errors.push(file.path + ": " + dimension + " differs")
      }
    }
    if file.same_mtime_as is Some(reference) {
      let other = entries.iter().find_first(entry => entry.path == reference)
      if !(other is Some(other) &&
        actual.metadata.get("mtime") is Some(time) &&
        other.metadata.get("mtime") == Some(time)) {
        errors.push(file.path + ": timestamp differs from " + reference)
      }
    }
    if file.unchanged == Some(true) {
      let before = baseline
        .unwrap_or([])
        .iter()
        .find_first(entry => entry.path == file.path)
      if !(before is Some(before) &&
        before.kind == actual.kind &&
        before.content == actual.content &&
        before.metadata == actual.metadata) {
        errors.push(
          file.path + ": changed from independently observed initial state",
        )
      }
    }
    for
      (dimension, reference, equal) in [
        ("mode", file.same_mode_as, true),
        ("identity", file.different_identity_as, false),
      ] {
      if reference is Some(reference) {
        let other = entries.iter().find_first(entry => entry.path == reference)
        if !(other is Some(other) &&
          actual.metadata.get(dimension) is Some(measured) &&
          other.metadata.get(dimension) is Some(control) &&
          (measured == control) == equal) {
          errors.push(
            file.path + ": " + dimension + " relation differs from " + reference,
          )
        }
      }
    }
  }
  errors
}

///|
pub extend CaseReport with ToJson::{to_json}

///|
pub extend CaseReport with @debug.Debug::{to_repr}
