///|
fn git_environment(values : Map[String, String]) -> Map[String, String] {
  let environment : Map[String, String] = Map([])
  for name, value in values {
    if !name.to_upper().has_prefix("GIT_") {
      environment[name] = value
    }
  }
  environment["GIT_OPTIONAL_LOCKS"] = "0"
  environment["GIT_NO_REPLACE_OBJECTS"] = "1"
  environment["LC_ALL"] = "C"
  environment
}

///|
fn git_checkout_value(key : String, value : String) -> String raise {
  let value = value.trim().to_owned().to_lower()
  match key {
    "core.autocrlf" if value == "input" => "input"
    "core.autocrlf" | "core.symlinks" | "core.fileMode" =>
      match value {
        "true" => "true"
        "false" => "false"
        _ => fail("scope Git rejects invalid checkout configuration: " + key)
      }
    "core.eol" if value is ("lf" | "crlf" | "native") => value
    _ => fail("scope Git rejects unsupported checkout configuration: " + key)
  }
}

///|
async fn git_checkout_configuration(
  root : String,
  environment : Map[String, String],
) -> Array[String] {
  let arguments : Array[String] = []
  // Reading these scalar settings invokes no checkout, filter or hook. Keep
  // the conversion that ordinary Git used for checkout, then pass only this
  // closed set through the command boundary that disables system config.
  for key in ["core.autocrlf", "core.eol", "core.symlinks", "core.fileMode"] {
    let format = match key {
      "core.autocrlf" => ["--type=bool-or-str"]
      "core.symlinks" | "core.fileMode" => ["--type=bool"]
      _ => []
    }
    let result = @shell.Cmd(
      "git",
      [
        "--no-replace-objects", "-c", "core.fsmonitor=false", "config", ..format,
        "--null", "--get", key,
      ],
      cwd=root,
      env=environment,
      inherit_env=false,
    ).output(timeout_ms=15000, max_output_bytes=65536)
    if result.exit_code() == 1 && result.stdout_bytes().is_empty() {
      continue
    }
    guard result.exit_code() == 0 else {
      fail(
        "scope Git cannot read checkout configuration: " +
        key +
        "\n" +
        result.stderr(),
      )
    }
    let records = git_nul_records(result.stdout_bytes())
    guard records is [record] else {
      fail(
        "scope Git checkout configuration must contain exactly one scalar: " +
        key,
      )
    }
    let value = git_checkout_value(
      key,
      git_utf8(record[:], "checkout configuration"),
    )
    arguments.append(["-c", key + "=" + value])
  }
  arguments
}

///|
async fn git_capture(
  root : String,
  arguments : Array[String],
  input? : String,
  index? : String,
  checkout? : Array[String],
) -> Bytes {
  let environment = git_environment(@env.get_env_vars())
  let checkout = match checkout {
    Some(values) => values
    None => git_checkout_configuration(root, environment)
  }
  environment["GIT_CONFIG_NOSYSTEM"] = "1"
  if index is Some(path) {
    environment["GIT_INDEX_FILE"] = path
  }
  let result = @shell.Cmd(
    "git",
    [
      "--no-replace-objects", "-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false",
      "-c", "core.ignoreStat=false", ..checkout, ..arguments,
    ],
    cwd=root,
    env=environment,
    inherit_env=false,
    stdin?=input.map(value => @shell.Stdin::Text(value)),
  ).output(timeout_ms=60000, max_output_bytes=134217728)
  guard result.exit_code() == 0 else {
    fail(
      "scope Git command failed: " +
      arguments.join(" ") +
      "\n" +
      result.stderr(),
    )
  }
  result.stdout_bytes()
}

///|
/// Shared shell-free Git text boundary for scope preparation and repository probes.
pub async fn scope_git_text(root : String, arguments : Array[String]) -> String {
  git_utf8(git_capture(git_root(root), arguments)[:], "text output")
  .trim()
  .to_owned()
}

///|
fn git_line(bytes : Bytes, context : String) -> String raise {
  guard !bytes.is_empty() && bytes[bytes.length() - 1] == b'\n' else {
    fail("scope Git " + context + " has no terminating newline")
  }
  git_utf8(bytes[:bytes.length() - 1], context)
}

///|
async fn git_root(root : String) -> String {
  let canonical = @fs.realpath(root)
  let reported = git_line(
    git_capture(canonical, ["rev-parse", "--show-toplevel"]),
    "root",
  )
  guard @fs.realpath(reported) == canonical else {
    fail("scope Git root must be the repository top-level directory")
  }
  canonical
}

///|
async fn git_resolve(root : String, revision : String, kind : String) -> String {
  guard !revision.is_empty() && !revision.contains("\u0000") else {
    fail("scope Git revision is empty or contains NUL")
  }
  let value = git_line(
    git_capture(root, [
      "rev-parse",
      "--verify",
      "--end-of-options",
      revision + "^{" + kind + "}",
    ]),
    "object ID",
  )
  guard git_oid(value) else { fail("scope Git returned an invalid object ID") }
  value
}

///|
/// Resolve a commit without accepting ambient Git directory, index or replace overrides.
pub async fn resolve_commit(root : String, revision : String) -> String {
  git_resolve(git_root(root), revision, "commit")
}

///|
/// Read immutable Git blobs; symbolic links remain their recorded link text.
/// Gitlinks, unsafe path components and non-UTF-8 paths fail closed instead of being omitted.
pub async fn read_tree(root : String, revision : String) -> TreeSnapshot {
  let root = git_root(root)
  let tree = git_resolve(root, revision, "tree")
  let files = git_tree_entries(
    git_capture(root, ["ls-tree", "-r", "-z", "--full-tree", tree, "--"]),
  )
  guard files.all(file => file.blob.length() == tree.length()) else {
    fail("scope Git tree contains inconsistent object ID widths")
  }
  if !files.is_empty() {
    let ids = files.map(file => file.blob)
    let contents = git_batch_blobs(
      git_capture(root, ["cat-file", "--batch"], input=ids.join("\n") + "\n"),
      ids,
    )
    for index in 0..<files.length() {
      files[index] = { ..files[index], content: contents[index], }
    }
  }
  { tree, files, }
}

///|
/// Preserve raw status, both names, full blob IDs and modes for the complete range.
pub async fn read_changes(
  root : String,
  base : String,
  head_tree : String,
) -> Array[GitChange] {
  let root = git_root(root)
  let base = git_resolve(root, base, "commit")
  let head = git_resolve(root, head_tree, "tree")
  git_raw_changes(
    git_capture(root, [
      "-c", "diff.renameLimit=0", "-c", "diff.algorithm=myers", "diff", "--raw",
      "--no-abbrev", "--full-index", "-z", "--find-renames=50%", "--no-ext-diff",
      "--no-textconv", "--no-color", "--ignore-submodules=none", base, head, "--",
    ]),
  )
}

///|
async fn git_require_staged_only(root : String) -> Unit {
  guard git_capture(root, ["ls-files", "--unmerged", "-z"]).is_empty() else {
    fail("scope Git requires a fully merged index")
  }
  for record in git_nul_records(git_capture(root, ["ls-files", "-v", "-z"])) {
    guard record.length() > 2 && record[0] == b'H' && record[1] == b' ' else {
      fail(
        "scope Git rejects assume-unchanged, skip-worktree or nonstandard index entries",
      )
    }
    git_safe_path(git_utf8(record[2:], "index path"))
  }
  guard git_capture(root, [
    "diff", "--raw", "--no-abbrev", "-z", "--no-renames", "--no-ext-diff", "--no-textconv",
    "--ignore-submodules=none", "--",
  ]).is_empty() else {
    fail(
      "scope Git requires all tracked edits to be staged, including ci-change.json",
    )
  }
  guard git_capture(root, ["ls-files", "--others", "--exclude-standard", "-z"]).is_empty() else {
    fail("scope Git requires all nonignored untracked paths to be staged")
  }
}

///|
fn git_worktree_diagnostics(differences : Bytes) -> Array[Json] raise {
  let records = git_nul_records(differences)
  guard records.length() % 2 == 0 else {
    fail("scope Git worktree diagnostic has an incomplete header or path")
  }
  let result : Array[Json] = []
  for index in 0..<(records.length() / 2) {
    let header = git_utf8(records[index * 2][:], "worktree diagnostic header")
    guard header.has_prefix(":") else {
      fail("scope Git worktree diagnostic header has no colon")
    }
    let fields = header[1:].split(" ").map(field => field.to_owned()).collect()
    guard fields is [old_mode, new_mode, old_blob, new_blob, status] &&
      git_mode(old_mode, absent=true) &&
      git_mode(new_mode, absent=true) &&
      git_oid(old_blob, zero=true) &&
      git_oid(new_blob, zero=true) &&
      old_blob.length() == new_blob.length() &&
      status is ("A" | "D" | "M" | "T") else {
      fail(
        "scope Git worktree diagnostic contains malformed modes, objects or status",
      )
    }
    let path = git_utf8(records[index * 2 + 1][:], "worktree diagnostic path")
    git_safe_path(path) catch {
      _ =>
        fail(
          "scope Git worktree diagnostic rejects unsafe path: " +
          Json(path).stringify(),
        )
    }
    result.push({
      "path": Json(path),
      "status": Json(status),
      "old_mode": Json(old_mode),
      "new_mode": Json(new_mode),
    })
  }
  result
}

///|
async fn git_require_fresh_worktree(
  root : String,
  tree : String,
  checkout? : Array[String],
) -> Unit {
  let checkout = match checkout {
    Some(values) => values
    None =>
      git_checkout_configuration(root, git_environment(@env.get_env_vars()))
  }
  let temporary = @fs.tmpdir(prefix="mooncmd-scope-index-")
  defer (@fs.rmdir(temporary, recursive=true) catch { _ => () })
  let index = temporary + "/index"
  // A newly read index has no trusted worktree stat cache. Git must inspect
  // file content and link text, applying the repository's checkout conversion.
  ignore(
    git_capture(
      root,
      ["read-tree", "--no-sparse-checkout", tree],
      index~,
      checkout~,
    ),
  )
  let mode = if @testkit.host_platform() == "windows" {
    []
  } else {
    ["-c", "core.fileMode=true"]
  }
  let differences = git_capture(
    root,
    [
      ..mode, "diff", "--raw", "--no-abbrev", "-z", "--no-renames", "--no-ext-diff",
      "--no-textconv", "--ignore-submodules=none", "--",
    ],
    index~,
    checkout~,
  )
  guard differences.is_empty() else {
    fail(
      "scope Git worktree content or mode differs from the freshly read staged tree: " +
      Json({
        "differences": Json(git_worktree_diagnostics(differences)),
        "checkout_conversion": Json(checkout),
      }).stringify(),
    )
  }
}

///|
/// Freeze the index only when every managed edit is staged. Temporary plans and
/// reports must live in ignored directories. Recheck around write-tree to catch races.
pub async fn staged_tree(root : String) -> String {
  let root = git_root(root)
  git_require_staged_only(root)
  let tree = git_line(git_capture(root, ["write-tree"]), "staged tree")
  guard git_oid(tree) else {
    fail("scope Git write-tree returned an invalid tree ID")
  }
  git_require_fresh_worktree(root, tree)
  git_require_staged_only(root)
  guard git_line(git_capture(root, ["write-tree"]), "staged tree") == tree else {
    fail("scope Git index changed while preparing its snapshot")
  }
  tree
}

///|
/// Exclude only the generated declaration, avoiding a hash of its own hash.
/// The tree object ID is deliberately absent; every other path, mode and byte is bound.
pub fn payload_digest(snapshot : TreeSnapshot) -> String {
  let rows = snapshot.files
    .filter(file => file.path != "tests/coverage/ci-change.json")
    .map(file => {
      Json({
        "path": Json(file.path),
        "mode": Json(file.mode),
        "blob": Json(file.blob),
        "sha256": Json(@testkit.sha256_bytes(file.content)),
      })
    })
  rows.sort_by_key(row => @testkit.canonical_json(row))
  @testkit.json_digest(
    Json({ "schema": Json("scope-payload-v1"), "files": Json(rows) }),
  )
}

///|
/// A rename crossing the declaration boundary remains bound in full: excluding
/// it could hide a payload addition or deletion. Only declaration-only rows vanish.
pub fn payload_changes(changes : Array[GitChange]) -> Array[GitChange] {
  let declaration = "tests/coverage/ci-change.json"
  changes.filter(change => {
    !((change.old_path == "" || change.old_path == declaration) &&
    (change.new_path == "" || change.new_path == declaration))
  })
}

///|
pub fn change_digest(changes : Array[GitChange]) -> String {
  let rows = payload_changes(changes).map(change => ToJson::to_json(change))
  rows.sort_by_key(row => @testkit.canonical_json(row))
  @testkit.json_digest(
    Json({ "schema": Json("scope-changes-v1"), "changes": Json(rows) }),
  )
}
