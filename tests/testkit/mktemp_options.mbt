///|
pub async fn check_mktemp_options(
  work : String,
  launch : async (Array[String], String, Map[String, String]) -> RunResult,
  check_mode~ : Bool,
) -> Unit {
  let cases = [
    ([], "<WORK>/tmp/tmp.", 10, "", false),
    (["name.XXX"], "name.", 3, "", false),
    (["name.XXX.tail"], "name.", 3, ".tail", false),
    (["--suffix=.tail", "name.XXX"], "name.", 3, ".tail", false),
    (["-p", "pdir", "name.XXX"], "pdir/name.", 3, "", false),
    (["--tmpdir", "name.XXX"], "<WORK>/tmp/name.", 3, "", false),
    (["--tmpdir=pdir", "nested/name.XXX"], "pdir/nested/name.", 3, "", false),
    (["-t", "-p", "pdir", "name.XXX"], "<WORK>/tmp/name.", 3, "", false),
    (["-d", "name.XXX"], "name.", 3, "", true),
    (["--tmpdir=", "name.XXX"], "<WORK>/tmp/name.", 3, "", false),
    (["-p", "pdir", "-t", "name.XXX"], "<WORK>/tmp/name.", 3, "", false),
    (["--", "--tmpdirXXX"], "--tmpdir", 3, "", false),
  ]
  let receipts : Array[Json] = []
  for index, (args, prefix, width, suffix, directory) in cases {
    let cwd = work + "/case-" + index.to_string()
    @fs.mkdir(cwd)
    @fs.mkdir(cwd + "/tmp")
    @fs.mkdir(cwd + "/pdir")
    @fs.mkdir(cwd + "/pdir/nested")
    let dimensions = if check_mode { ["mode"] } else { [] }
    let before = snapshot(cwd, observe=dimensions, content=false)
    let run = launch(args, cwd, Map([("TMPDIR", cwd + "/tmp")]))
    assert_eq(run.status, 0)
    assert_eq(run.stderr, b"")
    let stdout = @utf8.decode(run.stdout)
    assert_true(stdout.has_suffix("\n"))
    let name = stdout[:stdout.length() - 1]
      .to_owned()
      .replace_all(old="\\", new="/")
    let prefix = prefix.replace_all(
      old="<WORK>",
      new=cwd.replace_all(old="\\", new="/"),
    )
    assert_true(name.has_prefix(prefix) && name.has_suffix(suffix))
    assert_eq(name.length(), prefix.length() + width + suffix.length())
    assert_true(
      name[prefix.length():prefix.length() + width]
      .iter()
      .all(char => char is ('0'..<='9' | 'A'..<='Z' | 'a'..<='z')),
    )
    let path = if name.has_prefix(cwd.replace_all(old="\\", new="/") + "/") {
      name
    } else {
      cwd + "/" + name
    }
    let kind = @fs.kind(path, follow_symlink=false)
    assert_eq(kind, if directory { Directory } else { Regular })
    let empty = if directory {
      @fs.readdir(path).is_empty()
    } else {
      @fs.file_size(path) == 0L
    }
    assert_true(empty)
    let after = snapshot(cwd, observe=dimensions, content=false)
    for old in before {
      guard after.filter(entry => entry.path == old.path) is [entry] else {
        fail("mktemp removed an existing fixture path")
      }
      assert_eq(entry.kind, old.kind)
      assert_eq(entry.metadata, old.metadata)
    }
    let created = after.filter(entry => {
      !before.any(old => old.path == entry.path)
    })
    guard created is [entry] else {
      fail("mktemp must create exactly its reported path")
    }
    let relative = name
      .strip_prefix(cwd.replace_all(old="\\", new="/") + "/")
      .unwrap_or(name[:])
      .to_owned()
    assert_eq(entry.path.replace_all(old="\\", new="/"), relative)
    if check_mode {
      assert_eq(
        entry.metadata.get("mode"),
        Some(if directory { "700" } else { "600" }),
      )
    }
    // Record only relations already proved against this run. Raw stdout and
    // the randomly named file remain in the retained evidence directory.
    let receipt : Map[String, Json] = {
      "case": Json(index),
      "args": Json(args),
      "status": Json(run.status),
      "stderr": Json(@utf8.decode(run.stderr)),
      "prefix": Json(
        name[:prefix.length()]
        .to_owned()
        .replace_all(old=cwd.replace_all(old="\\", new="/"), new="${WORK}"),
      ),
      "width": Json(name.length() - prefix.length() - suffix.length()),
      "suffix": Json(name[name.length() - suffix.length():].to_owned()),
      "alphanumeric": Json(
        name[prefix.length():prefix.length() + width]
        .iter()
        .all(char => char is ('0'..<='9' | 'A'..<='Z' | 'a'..<='z')),
      ),
      "kind": Json(kind_name(kind)),
      "empty": Json(empty),
      "created_count": Json(created.length()),
      "reported_path_created": Json(
        entry.path.replace_all(old="\\", new="/") == relative,
      ),
      "existing_type_and_metadata_unchanged": Json(true),
      "stdout_newline": Json(stdout.has_suffix("\n")),
    }
    if check_mode {
      receipt["mode"] = Json(entry.metadata.get("mode").unwrap())
    }
    receipts.push(Json(receipt))
  }
  @fs.write_file(
    work + "/mktemp-relations.json",
    canonical_json({ "cases": Json(receipts) }),
  )
}

///|
pub async fn check_mktemp_oracle(work : String, image : String) -> Unit {
  @fs.mkdir(work)
  check_mktemp_options(
    work,
    (args, cwd, environment) => {
      let name = @path.Path(cwd).basename().to_owned()
      let invocation = [
        "run",
        "--rm",
        "-i",
        "--user",
        docker_user(),
        "-v",
        work + ":" + work + ":rw",
        "-w",
        cwd,
        "-e",
        "LC_ALL=C",
        "-e",
        "TMPDIR=" + environment["TMPDIR"],
        image,
        "mktemp",
        ..args,
      ]
      let run = run_oracle_with_deadline(
        "docker",
        invocation,
        15000,
        evidence_dir=work + "/oracle-lifecycle-" + name,
        stdin=b"",
      )
      @fs.write_file(work + "/" + name + ".stdout", run.output.stdout)
      @fs.write_file(work + "/" + name + ".stderr", run.output.stderr)
      guard !run.timed_out && run.cleanup_error is None else {
        fail("mktemp oracle lifecycle infrastructure failure")
      }
      run.output
    },
    check_mode=true,
  )
}
