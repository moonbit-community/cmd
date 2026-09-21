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
pub async fn write_reports(
  directory : String,
  reports : ArrayView[CaseReport],
) -> Unit {
  if !@fs.exists(directory) {
    @fs.mkdir(directory, recursive=true)
  }
  @fs.write_file(
    directory + "/summary.jsonl",
    reports.map(item => ToJson::to_json(item).stringify()).join("\n") + "\n",
  )
  let lines = StringBuilder()
  lines.write(
    "| Case | Result | Verification | Backend | ms | Stage | Detail |\n| --- | --- | --- | --- | --- | --- | --- |\n",
  )
  for item in reports {
    let detail = item.detail
      .replace_all(old="|", new="\\|")
      .replace_all(old="\n", new="<br>")
    lines.write(
      "| \{item.id} | \{item.result} | \{item.verification} | \{item.backend} | \{item.duration_ms} | \{item.stage} | \{detail} |\n",
    )
  }
  @fs.write_file(directory + "/summary.md", lines.to_string())
}

///|
pub fn contract_errors(fixture : Case) -> Array[String] {
  let errors : Array[String] = []
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
            "mode" => file.mode is Some(_)
            "identity" => file.same_identity_as is Some(_)
            "symlink-target" => file.target is Some(_)
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
      fixture.diagnostic_reason.unwrap_or("") == "" {
      errors.push("partial matching requires diagnostic_reason")
    }
  }
  errors
}

///|
pub fn check_contract(
  fixture : Case,
  result : RunResult,
  root : String,
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
        text.map(value => expand_text(value, root)),
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
fn unordered_lines_equal(left : Bytes, right : Bytes) -> Bool {
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
        (file.mode is Some(_), "mode"),
        (file.target is Some(_), "symlink-target"),
        (file.same_identity_as is Some(_), "identity"),
      ] {
      if needed && !dimensions.contains(name) {
        dimensions.push(name)
      }
    }
  }
  dimensions
}

///|
pub async fn check_expected_files(
  fixture : Case,
  root : String,
) -> Array[String] {
  let expected = fixture.expected_files.unwrap_or([])
  if expected.is_empty() {
    return []
  }
  let entries = snapshot(root, observe=contract_observations(fixture))
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
        file.content_text.map(value => expand_text(value, root)),
        file.path,
      )
      if actual.kind != "file" || actual.content != content {
        errors.push(file.path + ": content differs")
      }
    }
    if file.mode is Some(mode) {
      let measured = actual.metadata.get("mode").unwrap_or("")
      let parsed = @string.parse_int(measured, base=8) catch { _ => -1 }
      if parsed != mode {
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
  }
  errors
}
