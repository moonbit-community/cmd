///|
fn printf_state_vectors() -> Array[(String, String, String, String)] {
  let field = String::make(8191, ' ') + "y"
  let warning = "[diagnostic]"
  let vectors : Array[(String, String, String, String)] = []
  for
    (name, prefix, before, warm, error) in [
      ("cold", "", "", false, ""),
      ("printf", "printf x; ", "x", true, ""),
      ("echo", "echo x; ", "x\n", true, ""),
      ("empty-string", "printf '%s' ''; ", "", false, ""),
      ("zero-precision", "printf '%.0s' x; ", "", false, ""),
      ("stopped-empty", "printf '%b' '\\c'; ", "", false, ""),
      ("brace", "{ printf x; }; ", "x", true, ""),
      ("subshell", "(printf x); ", "x", false, ""),
      ("substitution", "v=$(printf x); ", "", false, ""),
      ("redirected", "printf x >&2; ", "", true, "x"),
    ] {
    vectors.push(
      (
        name,
        prefix + "printf '%8192s%d' y bad 2>&1",
        before + (if warm { warning + field } else { field + warning }) + "0",
        error,
      ),
    )
  }
  vectors.push(
    (
      "below",
      "printf '%8191s%d' y bad 2>&1",
      warning + String::make(8190, ' ') + "y0",
      "",
    ),
  )
  vectors.push(
    (
      "above",
      "printf '%8193s%d' y bad 2>&1",
      String::make(8192, ' ') + "y" + warning + "0",
      "",
    ),
  )
  let half = String::make(4095, ' ')
  vectors.push(
    (
      "repeated",
      "printf '%4096s%d' a 0 b bad 2>&1",
      half + "a0" + warning + half + "b0",
      "",
    ),
  )
  vectors
}

///|
fn normalize_printf_warning(output : Bytes, prefix : String) -> String raise {
  let text = @utf8.decode(output)
  guard text.find(prefix) is Some(start) else {
    fail("missing exact diagnostic prefix")
  }
  let rest = text[start:].to_owned()
  guard rest.find("\n") is Some(end) else { fail("unterminated diagnostic") }
  let diagnostic = rest[:end].to_owned()
  assert_true(diagnostic.contains("printf:"))
  assert_true(diagnostic.contains("bad:"))
  assert_true(diagnostic.contains("expected numeric value"))
  assert_false(rest[end + 1:].contains(prefix))
  text[:start].to_owned() + "[diagnostic]" + rest[end + 1:].to_owned()
}

///|
async fn printf_state_scenario(
  root : String,
  work : String,
  proof? : @harness.ScenarioProof,
  oracle_image? : String,
) -> Unit {
  for (name, source, expected, expected_error) in printf_state_vectors() {
    let product = scenario_run(
      work,
      root,
      "sh",
      ["-c", source, "printf-audit"],
      cwd=work,
    )
    let normalized = normalize_printf_warning(product.stdout, "sh: printf:")
    assert_eq(product.status, 1)
    assert_eq(normalized, expected)
    assert_eq(product.stderr, @utf8.encode(expected_error))
    if proof is Some(proof) {
      proof.observe_equal(
        "sh/printf-state-" + name,
        "sh",
        {
          "status": product.status,
          "stdout": normalized,
          "stderr": @harness.scenario_text(product.stderr),
        },
        { "status": 1, "stdout": expected, "stderr": expected_error },
      )
    }
    if oracle_image is Some(image) {
      let result = @harness.run_oracle_with_deadline(
        "docker",
        [
          "run", "--rm", "-i", image, "/oracle/bin/sh", "-c", source, "printf-audit",
        ],
        15000,
        evidence_dir=work + "/oracle-" + name + "-lifecycle",
        stdin=b"",
      )
      @fs.write_file(
        work + "/oracle-" + name + ".stdout.bin",
        result.output.stdout,
      )
      @fs.write_file(
        work + "/oracle-" + name + ".stderr.bin",
        result.output.stderr,
      )
      assert_false(result.timed_out)
      assert_eq(result.cleanup_error, None)
      assert_eq(result.output.status, 1)
      assert_eq(
        normalize_printf_warning(result.output.stdout, "printf-audit:"),
        expected,
      )
      assert_eq(result.output.stderr, @utf8.encode(expected_error))
    }
  }
}
