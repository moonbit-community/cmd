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
