///|
test "native path expectation templates preserve literal payload and legacy roots" {
  let template = "${WORK_NATIVE}${PATH_SEPARATOR}sub\nliteral\\tail"
  assert_eq(
    expand_native_path_templates(template, "D:\\a\\case/work", true),
    "D:\\a\\case\\work\\sub\nliteral\\tail",
  )
  assert_eq(
    expand_native_path_templates(template, "/case/work", false),
    "/case/work/sub\nliteral\\tail",
  )
  assert_eq(
    expand_native_path_templates("${WORK}/unchanged", "D:\\a/case", true),
    "${WORK}/unchanged",
  )
  assert_eq(
    expand_text("${WORK}/unchanged", "D:\\a/case"),
    "D:\\a/case/unchanged",
  )
}

///|
test "exact host path contracts reject wrong directories and changed payload" {
  let root = "/case/work"
  let directory = {
    ..sample_case("host-cwd", "env"),
    expected_stdout_text: Some("${WORK_NATIVE}${PATH_SEPARATOR}sub\n"),
    expected_stderr_text: Some(""),
  }
  let expected = expand_text(directory.expected_stdout_text.unwrap(), root)
  assert_eq(
    check_contract(
      directory,
      { status: 0, stdout: @utf8.encode(expected), stderr: b"", },
      root,
    ),
    [],
  )
  for
    changed in [
      expand_text("${WORK_NATIVE}\n", root),
      expand_text("${WORK_NATIVE}${PATH_SEPARATOR}other\n", root),
    ] {
    assert_false(
      check_contract(
        directory,
        { status: 0, stdout: @utf8.encode(changed), stderr: b"", },
        root,
      ).is_empty(),
    )
  }
  let control = { ..directory, expected_stdout_text: Some("${WORK_NATIVE}\n"), }
  assert_false(
    check_contract(
      control,
      { status: 0, stdout: @utf8.encode(expected), stderr: b"", },
      root,
    ).is_empty(),
  )
  let grep = {
    ..sample_case("host-grep", "grep"),
    expected_stdout_text: Some(
      "tree${PATH_SEPARATOR}keep.txt:literal\\needle\n",
    ),
    expected_stderr_text: Some(""),
  }
  let output = expand_text(grep.expected_stdout_text.unwrap(), root)
  assert_eq(
    check_contract(
      grep,
      { status: 0, stdout: @utf8.encode(output), stderr: b"", },
      root,
    ),
    [],
  )
  for
    changed in [
      output.replace_all(old="keep.txt", new="skip.txt"),
      output.replace_all(old="literal\\needle", new="literal/needle"),
      output.replace_all(old="\n", new="\r\n"),
      output + "extra\n",
    ] {
    assert_false(
      check_contract(
        grep,
        { status: 0, stdout: @utf8.encode(changed), stderr: b"", },
        root,
      ).is_empty(),
    )
  }
}

///|
test "hex fixtures preserve arbitrary bytes" {
  assert_eq(decode_hex("00ff4162", "fixture"), b"\x00\xffAb")
  try decode_hex("0", "fixture") catch {
    _ => ()
  } noraise {
    _ => fail("odd hexadecimal input must fail")
  }
  try decode_hex("xz", "fixture") catch {
    _ => ()
  } noraise {
    _ => fail("non-hexadecimal input must fail")
  }
}

///|
test "fixture content expands HTTP placeholders after decoding" {
  let base = "http://127.0.0.1:12345"
  assert_eq(
    expand_fixture_content(b"${HTTP_BASE}/fixed\n", http_base=base),
    b"http://127.0.0.1:12345/fixed\n",
  )
  assert_eq(
    expand_fixture_content(b"plain text", http_base=base),
    b"plain text",
  )
  assert_eq(
    expand_fixture_content(b"\xff${HTTP_BASE}", http_base=base),
    b"\xff${HTTP_BASE}",
  )
}

///|
test "fixture paths cannot escape an isolated work directory" {
  assert_true(safe_relative_path("input/data.bin"))
  assert_true(safe_relative_path("nested/file"))
  assert_false(safe_relative_path(""))
  assert_false(safe_relative_path("/absolute"))
  assert_false(safe_relative_path("../escape"))
  assert_false(safe_relative_path("nested/../escape"))
  assert_false(safe_relative_path("nested\\..\\escape"))
  assert_false(safe_relative_path("C:/outside"))
  assert_true(safe_symlink_target("target"))
  assert_false(safe_symlink_target("../outside"))
  assert_false(safe_symlink_target("/absolute"))
}

///|
test "undeclared normalization preserves binary bytes" {
  let binary = b"\x00\xff\r\n"
  assert_true(
    bytes_equal(normalize_text(binary, "stdout", [], "/tmp/case"), binary),
  )
}

///|
test "working-directory normalization maps local and container roots" {
  let rules : Array[Normalization] = [
    {
      field: "stdout",
      rule: "working-directory",
      comment: "oracle containers mount each case at /work",
    },
  ]
  assert_eq(
    normalize_text(b"/tmp/case/sub\n", "stdout", rules, "/tmp/case"),
    b"<WORK>/sub\n",
  )
  assert_eq(
    normalize_text(b"/work/sub\n", "stdout", rules, "/oracle/root"),
    b"<WORK>/sub\n",
  )
}

///|
test "fixture prefix normalization handles mixed Windows separators" {
  let rules : Array[Normalization] = [
    { field: "stdout", rule: "temporary-path", comment: "fixture prefix", },
    {
      field: "stdout",
      rule: "path-separator",
      comment: "Windows slash variants",
    },
  ]
  assert_eq(
    normalize_text(
      b"D:\\a\\case\\work\\file\n", "stdout", rules, "D:\\a\\case/work",
    ),
    b"<TMP>/file\n",
  )
}

///|
test "release contract newline checks exactly one terminator" {
  assert_true(ends_with_newline(b"line\n"))
  assert_false(ends_with_newline(b"line\n\n"))
  assert_false(ends_with_newline(b"line"))
  assert_false(ends_with_newline(b""))
}

///|
test "Windows link observer distinguishes symbolic links and junction targets" {
  assert_eq(
    windows_link_observation(
      b"{\"kind\":\"SymbolicLink\",\"target\":\"referent\"}", "C:/work",
    ),
    ("SymbolicLink", "referent"),
  )
  assert_eq(
    windows_link_observation(
      b"{\"kind\":\"Junction\",\"target\":\"C:\\\\work\\\\referent\"}", "c:/work",
    ),
    ("Junction", "${WORK}/referent"),
  )
  assert_eq(
    windows_link_observation(
      b"{\"kind\":\"Junction\",\"target\":\"C:\\\\work-other\\\\referent\"}", "C:/work",
    ),
    ("Junction", "C:/work-other/referent"),
  )
}

///|
test "Windows link observer rejects missing or unrecognized reparse properties" {
  for
    data in [
      b"{\"kind\":null,\"target\":null}", b"{\"kind\":\"Other\",\"target\":\"referent\"}",
      b"{\"kind\":\"SymbolicLink\",\"target\":\"\"}",
    ] {
    try windows_link_observation(data, "C:/work") catch {
      _ => ()
    } noraise {
      _ => fail("unavailable link metadata must fail observation")
    }
  }
}
