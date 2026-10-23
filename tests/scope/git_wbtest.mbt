///|
async fn scope_fixture_git(
  root : String,
  arguments : Array[String],
  input? : String,
) -> Bytes {
  git_capture(
    root,
    [
      "-c",
      "user.name=Scope Fixture",
      "-c",
      "user.email=scope@example.invalid",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "core.autocrlf=false",
      "-c",
      "core.hooksPath=" + root + "/empty-hooks",
      "-c",
      "init.templateDir=" + root + "/empty-hooks",
      ..arguments,
    ],
    input?,
  )
}

///|
async fn scope_git_fixture() -> String {
  let root = @fs.tmpdir(prefix="mooncmd-scope-git-")
  @fs.mkdir(root + "/empty-hooks")
  @fs.mkdir(root + "/.scope-output")
  @fs.write_file(root + "/.gitignore", "/empty-hooks/\n/.scope-output/\n")
  ignore(scope_fixture_git(root, ["init", "--quiet", "--object-format=sha1"]))
  root
}

///|
async fn scope_git_commit(root : String) -> String {
  ignore(scope_fixture_git(root, ["add", "--all"]))
  ignore(scope_fixture_git(root, ["commit", "--quiet", "-m", "scope fixture"]))
  resolve_commit(root, "HEAD")
}

///|
async fn scope_expect_unstaged(root : String) -> Unit {
  try staged_tree(root) catch {
    _ => ()
  } noraise {
    _ =>
      fail("a managed edit or hidden index flag must reject scope preparation")
  }
}

///|
async fn scope_checkout_probe_environment(
  root : String,
  configuration : String,
) -> Map[String, String] {
  let home = root + "/.scope-output/config-home"
  @fs.mkdir(home, recursive=true, allow_exist=true)
  let environment = git_environment(@env.get_env_vars())
  environment["HOME"] = home
  environment["USERPROFILE"] = home
  environment["XDG_CONFIG_HOME"] = home
  // Only the read-only configuration probe sees this owned fixture file.
  environment["GIT_CONFIG_SYSTEM"] = configuration
  environment
}

///|
async test "scope Git preserves system checkout conversion in a fresh index" {
  let root = scope_git_fixture()
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/.gitattributes", "README.md -filter\n")
  @fs.write_file(root + "/README.md", "first\nsecond\n")
  ignore(scope_git_commit(root))
  let tree = git_line(scope_fixture_git(root, ["write-tree"]), "fixture tree")
  let configuration = root + "/.scope-output/system.gitconfig"
  @fs.write_file(
    configuration, "[core]\n\tautocrlf\n\teol = crlf\n\tsymlinks =\n",
  )
  let environment = scope_checkout_probe_environment(root, configuration)
  let preserved = git_checkout_configuration(root, environment)
  assert_true(preserved.contains("core.autocrlf=true"))
  assert_true(preserved.contains("core.eol=crlf"))
  assert_true(preserved.contains("core.symlinks=false"))
  let suppressed_environment = environment.copy()
  suppressed_environment["GIT_CONFIG_NOSYSTEM"] = "1"
  let suppressed = git_checkout_configuration(root, suppressed_environment)
  assert_true(!suppressed.any(value => value.has_prefix("core.autocrlf=")))
  assert_true(!suppressed.any(value => value.has_prefix("core.eol=")))
  @fs.remove(root + "/README.md")
  ignore(
    git_capture(root, [
      "-c", "core.autocrlf=true", "-c", "core.eol=crlf", "checkout-index", "--force",
      "--", "README.md",
    ]),
  )
  assert_eq(@fs.read_file(root + "/README.md").binary(), b"first\r\nsecond\r\n")
  // The old NOSYSTEM boundary lost these effective system settings. Explicit
  // default values isolate that failure mechanism from the host's global config.
  try
    git_require_fresh_worktree(
      root,
      tree,
      checkout=[
        ..suppressed, "-c", "core.autocrlf=false", "-c", "core.eol=native",
      ],
    )
  catch {
    error => {
      let detail = error.to_string()
      assert_true(detail.contains("\"path\":\"README.md\""))
      assert_true(detail.contains("\"status\":\"M\""))
      assert_true(!detail.contains("first"))
    }
  } noraise {
    _ =>
      fail(
        "discarding the checkout conversion must reproduce the CRLF false failure",
      )
  }
  git_require_fresh_worktree(root, tree, checkout=preserved)
  let snapshot = read_tree(root, tree)
  assert_true(
    snapshot.files.any(file => {
      file.path == "README.md" && file.content == b"first\nsecond\n"
    }),
  )
  // Equal-length edits must still fail with conversion enabled and a fresh index.
  @fs.write_file(root + "/README.md", b"other\r\nsecond\r\n")
  try git_require_fresh_worktree(root, tree, checkout=preserved) catch {
    error => assert_true(error.to_string().contains("\"path\":\"README.md\""))
  } noraise {
    _ => fail("checkout conversion must not hide a changed payload")
  }
  assert_eq(
    git_line(scope_fixture_git(root, ["write-tree"]), "fixture tree"),
    tree,
  )
}

///|
async test "scope Git preserves configured symbolic link stubs without following them" {
  let root = scope_git_fixture()
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/outside-target.mbt", "unrelated bytes")
  ignore(scope_git_commit(root))
  let target = "../outside-target.mbt"
  let blob = git_line(
    scope_fixture_git(root, ["hash-object", "-w", "--stdin"], input=target),
    "link blob",
  )
  ignore(
    scope_fixture_git(root, [
      "update-index", "--add", "--cacheinfo", "120000", blob, "link.mbt",
    ]),
  )
  ignore(scope_fixture_git(root, ["config", "core.symlinks", "false"]))
  ignore(
    scope_fixture_git(root, ["checkout-index", "--force", "--", "link.mbt"]),
  )
  let tree = git_line(scope_fixture_git(root, ["write-tree"]), "fixture tree")
  assert_eq(@fs.read_file(root + "/link.mbt").binary(), @utf8.encode(target))
  let settings = git_checkout_configuration(
    root,
    git_environment(@env.get_env_vars()),
  )
  assert_true(settings.contains("core.symlinks=false"))
  git_require_fresh_worktree(root, tree, checkout=settings)
  @fs.write_file(root + "/link.mbt", "../different-target.mbt")
  try git_require_fresh_worktree(root, tree, checkout=settings) catch {
    error => assert_true(error.to_string().contains("\"path\":\"link.mbt\""))
  } noraise {
    _ =>
      fail(
        "modified symbolic link text must fail even when checkout uses a regular stub",
      )
  }
  assert_true(
    read_tree(root, tree).files.any(file => {
      file.path == "link.mbt" &&
      file.mode == "120000" &&
      file.content == @utf8.encode(target)
    }),
  )
}

///|
test "scope Git checkout configuration is closed and ambient Git overrides are stripped" {
  let environment = git_environment({
    "GIT_DIR": "/untrusted",
    "git_index_file": "/untrusted/index",
    "GIT_CONFIG_SYSTEM": "/untrusted/config",
    "Git_Config_NoSystem": "1",
    "PATH": "/fixture/bin",
    "HOME": "/fixture/home",
  })
  assert_true(
    environment
    .keys()
    .all(name => {
      !name.to_upper().has_prefix("GIT_") ||
      name is ("GIT_OPTIONAL_LOCKS" | "GIT_NO_REPLACE_OBJECTS")
    }),
  )
  assert_eq(environment["PATH"], "/fixture/bin")
  assert_eq(environment["HOME"], "/fixture/home")
  assert_eq(git_checkout_value("core.autocrlf", "input"), "input")
  assert_eq(git_checkout_value("core.autocrlf", "true"), "true")
  assert_eq(git_checkout_value("core.symlinks", "false"), "false")
  assert_eq(git_checkout_value("core.fileMode", "true"), "true")
  assert_eq(git_checkout_value("core.eol", "crlf"), "crlf")
  for
    pair in [
      ("core.eol", "arbitrary"),
      ("core.autocrlf", "command"),
      ("core.fileMode", "true\nfalse"),
      ("core.symlinks", "input"),
      ("core.symlinks", ""),
      ("filter.fixture.clean", "arbitrary helper"),
    ] {
    try git_checkout_value(pair.0, pair.1) catch {
      _ => ()
    } noraise {
      _ =>
        fail(
          "unknown settings and non-scalar conversion values must fail closed",
        )
    }
  }
  let header = ":100644 100644 " +
    "a".repeat(40) +
    " " +
    "0".repeat(40) +
    " M\u0000"
  for suffix in ["../outside\u0000", ".git/config\u0000", "missing terminator"] {
    try git_worktree_diagnostics(@utf8.encode(header + suffix)) catch {
      _ => ()
    } noraise {
      _ => fail("worktree diagnostics must reject unsafe or malformed paths")
    }
  }
}

///|
async test "scope Git binds binary empty and symbolic link blobs from the index" {
  let root = scope_git_fixture()
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let binary = b"\x00\xff\nobject\x00tail"
  @fs.write_file(root + "/binary.mbt", binary)
  @fs.write_file(root + "/empty.mbt", b"")
  // Git permits tabs and newlines in names on Unix; they are not field delimiters.
  let odd = if @testkit.host_platform() == "windows" {
    "a name with spaces.mbt"
  } else {
    "a\tname\nwith spaces.mbt"
  }
  @fs.write_file(root + "/" + odd, "tracked path bytes")
  ignore(scope_fixture_git(root, ["add", "--all"]))
  let target = "../outside-the-repository"
  let link_blob = git_line(
    scope_fixture_git(root, ["hash-object", "-w", "--stdin"], input=target),
    "fixture link blob",
  )
  ignore(
    scope_fixture_git(root, [
      "update-index", "--add", "--cacheinfo", "120000", link_blob, "link",
    ]),
  )
  let tree = git_line(scope_fixture_git(root, ["write-tree"]), "fixture tree")
  let snapshot = read_tree(root, tree)
  assert_eq(snapshot.tree, tree)
  assert_eq(snapshot.files.length(), 5)
  assert_true(
    snapshot.files.any(file => {
      file.path == "binary.mbt" && file.content == binary
    }),
  )
  assert_true(
    snapshot.files.any(file => file.path == "empty.mbt" && file.content == b""),
  )
  assert_true(
    snapshot.files.any(file => {
      file.path == odd && file.content == b"tracked path bytes"
    }),
  )
  assert_true(
    snapshot.files.any(file => {
      file.path == "link" &&
      file.mode == "120000" &&
      file.blob == link_blob &&
      file.content == @utf8.encode(target)
    }),
  )
  // A later worktree write cannot alter an immutable tree snapshot.
  @fs.write_file(root + "/binary.mbt", b"later unstaged bytes")
  let reread = read_tree(root, tree)
  assert_eq(payload_digest(reread), payload_digest(snapshot))
}

///|
async test "scope Git range preserves rename deletion executable mode and type changes" {
  let root = scope_git_fixture()
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  for name in ["old name.mbt", "deleted.mbt", "mode.mbt", "type.mbt"] {
    @fs.write_file(root + "/" + name, name + " unique content\n")
  }
  @fs.write_file(root + "/binary.mbt", b"\x00\xffold")
  let retained = "unique edited rename line retained\n".repeat(20)
  @fs.write_file(root + "/edited old.mbt", retained + "old final line\n")
  let base = scope_git_commit(root)
  ignore(scope_fixture_git(root, ["mv", "old name.mbt", "new name.mbt"]))
  ignore(scope_fixture_git(root, ["mv", "edited old.mbt", "edited new.mbt"]))
  @fs.write_file(root + "/edited new.mbt", retained + "different final line\n")
  ignore(scope_fixture_git(root, ["add", "edited new.mbt"]))
  ignore(scope_fixture_git(root, ["rm", "--quiet", "deleted.mbt"]))
  ignore(scope_fixture_git(root, ["update-index", "--chmod=+x", "mode.mbt"]))
  let link_blob = git_line(
    scope_fixture_git(
      root,
      ["hash-object", "-w", "--stdin"],
      input="../not-read",
    ),
    "fixture blob",
  )
  ignore(
    scope_fixture_git(root, [
      "update-index", "--cacheinfo", "120000", link_blob, "type.mbt",
    ]),
  )
  @fs.write_file(root + "/binary.mbt", b"\x00\xffnew\n")
  ignore(scope_fixture_git(root, ["add", "binary.mbt"]))
  let tree = git_line(scope_fixture_git(root, ["write-tree"]), "fixture tree")
  let changes = read_changes(root, base, tree)
  assert_eq(changes.length(), 6)
  assert_true(
    changes.any(change => {
      change.status == "R100" &&
      change.old_path == "old name.mbt" &&
      change.new_path == "new name.mbt" &&
      change.old_blob == change.new_blob
    }),
  )
  assert_true(
    changes.any(change => {
      change.status.has_prefix("R") &&
      change.status != "R100" &&
      change.old_path == "edited old.mbt" &&
      change.new_path == "edited new.mbt" &&
      change.old_blob != change.new_blob
    }),
  )
  assert_true(
    changes.any(change => {
      change.status == "D" &&
      change.old_path == "deleted.mbt" &&
      change.new_path == "" &&
      change.new_mode == "000000" &&
      change.new_blob == "0".repeat(40)
    }),
  )
  assert_true(
    changes.any(change => {
      change.status == "M" &&
      change.old_path == "mode.mbt" &&
      change.old_mode == "100644" &&
      change.new_mode == "100755" &&
      change.old_blob == change.new_blob
    }),
  )
  assert_true(
    changes.any(change => {
      change.status == "T" &&
      change.new_path == "type.mbt" &&
      change.old_mode == "100644" &&
      change.new_mode == "120000" &&
      change.new_blob == link_blob
    }),
  )
  assert_true(
    changes.any(change => {
      change.status == "M" &&
      change.new_path == "binary.mbt" &&
      change.old_blob != change.new_blob
    }),
  )
}

///|
async test "scope Git staged preparation rejects post-prepare edits and hidden index flags" {
  let root = scope_git_fixture()
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.mkdir(root + "/tests/coverage", recursive=true)
  @fs.write_file(root + "/source.mbt", "base")
  @fs.write_file(root + "/tests/coverage/ci-change.json", "{}")
  let base = scope_git_commit(root)
  @fs.write_file(root + "/source.mbt", "staged source")
  scope_expect_unstaged(root)
  ignore(scope_fixture_git(root, ["add", "source.mbt"]))
  let prepared = staged_tree(root)
  @fs.write_file(
    root + "/.scope-output/intent.json",
    "temporary ignored output",
  )
  assert_eq(staged_tree(root), prepared)
  @fs.write_file(root + "/source.mbt", "changed after prepare")
  scope_expect_unstaged(root)
  @fs.write_file(root + "/source.mbt", "staged source")
  @fs.write_file(root + "/new.mbt", b"")
  scope_expect_unstaged(root)
  ignore(scope_fixture_git(root, ["add", "new.mbt"]))
  let payload_tree = staged_tree(root)
  assert_true(payload_tree != prepared)
  @fs.write_file(root + "/tests/coverage/ci-change.json", "{\"prepared\":true}")
  scope_expect_unstaged(root)
  ignore(scope_fixture_git(root, ["add", "tests/coverage/ci-change.json"]))
  let declared_tree = staged_tree(root)
  assert_true(declared_tree != payload_tree)
  assert_eq(
    payload_digest(read_tree(root, payload_tree)),
    payload_digest(read_tree(root, declared_tree)),
  )
  assert_eq(
    change_digest(read_changes(root, base, payload_tree)),
    change_digest(read_changes(root, base, declared_tree)),
  )
  ignore(
    scope_fixture_git(root, ["update-index", "--assume-unchanged", "source.mbt"]),
  )
  scope_expect_unstaged(root)
  ignore(
    scope_fixture_git(root, [
      "update-index", "--no-assume-unchanged", "source.mbt",
    ]),
  )
  ignore(
    scope_fixture_git(root, ["update-index", "--skip-worktree", "source.mbt"]),
  )
  scope_expect_unstaged(root)
  ignore(
    scope_fixture_git(root, ["update-index", "--no-skip-worktree", "source.mbt"]),
  )
  assert_eq(staged_tree(root), declared_tree)
  if @testkit.host_platform() != "windows" {
    // A repository setting must not hide an executable-mode worktree edit.
    ignore(scope_fixture_git(root, ["config", "core.fileMode", "false"]))
    @fs.chmod(root + "/source.mbt", 0o755)
    scope_expect_unstaged(root)
    @fs.chmod(root + "/source.mbt", 0o644)
    assert_eq(staged_tree(root), declared_tree)
  }
}

///|
async test "scope Git freshness survives a commit-message-only amendment" {
  let root = scope_git_fixture()
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/source.mbt", "base source")
  let base = scope_git_commit(root)
  @fs.write_file(root + "/source.mbt", "prepared source")
  ignore(scope_fixture_git(root, ["add", "source.mbt"]))
  let prepared_tree = staged_tree(root)
  let prepared_payload = payload_digest(read_tree(root, prepared_tree))
  let prepared_changes = change_digest(read_changes(root, base, prepared_tree))
  ignore(
    scope_fixture_git(root, ["commit", "--quiet", "-m", "first review title"]),
  )
  let first = resolve_commit(root, "HEAD")
  ignore(
    scope_fixture_git(root, [
      "commit", "--amend", "--quiet", "-m", "clarified review title",
    ]),
  )
  let amended = resolve_commit(root, "HEAD")
  assert_true(first != amended)
  assert_eq(read_tree(root, first).tree, prepared_tree)
  assert_eq(read_tree(root, amended).tree, prepared_tree)
  assert_eq(staged_tree(root), prepared_tree)
  assert_eq(payload_digest(read_tree(root, amended)), prepared_payload)
  assert_eq(change_digest(read_changes(root, base, amended)), prepared_changes)
}

///|
test "scope Git parsers reject truncated unsafe ambiguous and substituted data" {
  let a = "a".repeat(40)
  let b = "b".repeat(40)
  for
    bytes in [
      @utf8.encode("100644 blob " + a + "\tpath"),
      @utf8.encode("100644 blob " + a + "\t../outside\u0000"),
      @utf8.encode("100644 blob " + a + "\tC:stream\u0000"),
      @utf8.encode("100644 blob " + a + "\t.git/config\u0000"),
      @utf8.encode("160000 commit " + a + "\tsubmodule\u0000"),
      @utf8.encode(
        "100644 blob " + a + "\tsame\u0000100644 blob " + b + "\tsame\u0000",
      ),
      @utf8.encode("100644 blob " + a + "\t") + b"\xff\x00",
    ] {
    try git_tree_entries(bytes) catch {
      _ => ()
    } noraise {
      _ => fail("invalid tree data must fail closed")
    }
  }
  let header = ":100644 100644 " + a + " " + b + " "
  let renamed = git_raw_changes(
    @utf8.encode(header + "R86\u0000old\u0000new\u0000"),
  )
  assert_eq(renamed.length(), 1)
  assert_eq(renamed[0].status, "R86")
  for
    bytes in [
      @utf8.encode(header + "R100\u0000old\u0000"),
      @utf8.encode(header + "R101\u0000old\u0000new\u0000"),
      @utf8.encode(header + "U\u0000path\u0000"),
      @utf8.encode(header + "A\u0000path\u0000"),
      @utf8.encode(header + "M\u0000path\u0000extra\u0000"),
      @utf8.encode(header + "M\u0000path\u0000" + header + "M\u0000path\u0000"),
    ] {
    try git_raw_changes(bytes) catch {
      _ => ()
    } noraise {
      _ => fail("invalid raw diff data must fail closed")
    }
  }
  for
    bytes in [
      @utf8.encode(a + " blob 3\n") + b"ab\n",
      @utf8.encode(b + " blob 0\n\n"),
      @utf8.encode(a + " blob 0\n\ntrailing"),
      @utf8.encode(a + " blob 9999999999999999999999999\n\n"),
    ] {
    try git_batch_blobs(bytes, [a]) catch {
      _ => ()
    } noraise {
      _ => fail("invalid or substituted batch blobs must fail closed")
    }
  }
  assert_eq(git_batch_blobs(@utf8.encode(a + " blob 0\n\n"), [a]), [b""])
  assert_eq(
    git_batch_blobs(@utf8.encode(a + " blob 4\n") + b"\x00\xff\n\x00\n", [a]),
    [b"\x00\xff\n\x00"],
  )
}

///|
test "scope Git digest exclusions retain every payload path and cross-boundary rename" {
  let a = "a".repeat(40)
  let b = "b".repeat(40)
  let payload : TreeFile = {
    path: "docs/reports/result.json",
    mode: "100644",
    blob: a,
    content: b"one",
  }
  let declaration : TreeFile = {
    path: "tests/coverage/ci-change.json",
    mode: "100644",
    blob: b,
    content: b"{}",
  }
  let first : TreeSnapshot = { tree: a, files: [payload, declaration], }
  let declared : TreeSnapshot = {
    tree: b,
    files: [{ ..declaration, content: b"new declaration", }, payload],
  }
  assert_eq(payload_digest(first), payload_digest(declared))
  assert_true(
    payload_digest(first) !=
    payload_digest({
      tree: a,
      files: [{ ..payload, content: b"two", }, declaration],
    }),
  )
  assert_true(
    payload_digest(first) !=
    payload_digest({
      tree: a,
      files: [{ ..payload, mode: "100755", }, declaration],
    }),
  )
  assert_true(
    payload_digest(first) != payload_digest({ tree: a, files: [declaration], }),
  )
  let declaration_change : GitChange = {
    status: "M",
    old_path: declaration.path,
    new_path: declaration.path,
    old_mode: "100644",
    new_mode: "100644",
    old_blob: a,
    new_blob: b,
  }
  assert_eq(payload_changes([declaration_change]), [])
  assert_eq(change_digest([declaration_change]), change_digest([]))
  let crossing = {
    ..declaration_change,
    status: "R100",
    old_path: payload.path,
  }
  assert_eq(payload_changes([crossing]), [crossing])
  assert_true(change_digest([crossing]) != change_digest([]))
  let payload_change = {
    ..declaration_change,
    old_path: payload.path,
    new_path: payload.path,
  }
  assert_eq(
    change_digest([payload_change, declaration_change]),
    change_digest([payload_change]),
  )
}
