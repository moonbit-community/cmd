///|
fn link_move_options() -> MvOptions {
  {
    no_clobber: false,
    interactive: false,
    no_target_directory: true,
    verbose: false,
    update: @fsops.UpdateAll,
    backup: @fsops.NoBackup,
    suffix: "~",
  }
}

///|
async fn assert_windows_link_type(
  path : String,
  expected : String,
  target? : String,
) -> Unit {
  let (status, output) = @async.with_timeout(10000, () => {
    @process.collect_stdout(
      "powershell.exe",
      [
        "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); $item = Get-Item -LiteralPath $env:MOONCMD_OBSERVED_LINK -Force; [pscustomobject]@{kind=$item.LinkType; target=@($item.Target)[0]} | ConvertTo-Json -Compress",
      ],
      extra_env=Map([("MOONCMD_OBSERVED_LINK", path)]),
    )
  }) catch {
    error => fail("required Windows link observer unavailable: \{error}")
  }
  guard status == 0 else {
    fail("required Windows link observer exited with status \{status}")
  }
  let observation = @json.parse(output.text()) catch {
    error => fail("invalid Windows link observation: \{error}")
  }
  guard observation is { "kind": String(kind), .. } else {
    fail("required Windows link observer did not report LinkType")
  }
  assert_eq(kind, expected)
  if target is Some(expected_target) {
    guard observation is { "target": String(actual), .. } else {
      fail("required Windows link observer did not report Target")
    }
    let actual = actual.replace_all(old="\\", new="/")
    let normalized = if actual.has_prefix("//?/") {
      actual[4:].to_owned()
    } else {
      actual
    }
    assert_eq(
      normalized.to_lower(),
      expected_target.replace_all(old="\\", new="/").to_lower(),
    )
  }
}

///|
async fn check_link_move(directory : Bool, force_symlink : Bool) -> Unit {
  let root = @fs.tmpdir(prefix="mooncmd-mv-link")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let referent = @fsops.join(root, "referent")
  let content_path = if directory {
    @fs.mkdir(referent)
    @fsops.join(referent, "payload")
  } else {
    referent
  }
  @fs.write_file(content_path, b"referent must stay here\n")
  let referent_path = @fs.realpath(referent)
  let source = @fsops.join(root, "source")
  let moved = @fsops.join(root, "moved")
  @fs.symlink(target=referent_path, source, force_symlink~)
  assert_true(@fs.kind(source, follow_symlink=false) is SymLink)
  let expected_link_type = if force_symlink {
    "SymbolicLink"
  } else {
    "Junction"
  }
  if @async.platform is Windows {
    assert_windows_link_type(source, expected_link_type)
  }
  if unverified_windows_link_rename() {
    try move_one(source, moved, link_move_options()) catch {
      @fsops.FsOpError(message) =>
        assert_eq(
          message, "unsupported capability: Windows Wasm symlink/junction rename requires a verified host fix",
        )
      error => raise error
    } noraise {
      _ => fail("Windows Wasm must reject an unverified host link rename")
    }
    assert_true(@fs.kind(source, follow_symlink=false) is SymLink)
    assert_true(@fsops.kind_if_exists(moved) is None)
    assert_eq(@fs.realpath(source), referent_path)
    assert_windows_link_type(source, expected_link_type)
  } else {
    assert_true(move_one(source, moved, link_move_options()) is Moved)
    assert_true(@fsops.kind_if_exists(source) is None)
    assert_true(@fs.kind(moved, follow_symlink=false) is SymLink)
    assert_eq(@fs.realpath(moved), referent_path)
    if @async.platform is Windows {
      assert_windows_link_type(moved, expected_link_type)
    }
  }
  assert_eq(@fs.read_file(content_path).binary(), b"referent must stay here\n")
  assert_eq(@fs.realpath(referent), referent_path)
  assert_true(@fsops.kind_if_exists(moved + "~") is None)
}

///|
async test "mv moves or safely refuses a file symbolic link without moving its referent" {
  check_link_move(false, true)
}

///|
async test "mv moves or safely refuses a directory symbolic link without moving its referent" {
  check_link_move(true, true)
}

///|
async test "mv moves or safely refuses a Windows junction without moving its referent" {
  if @async.platform is Windows {
    check_link_move(true, false)
  }
}

///|
async test "mv backup preserves a destination link referent or rejects before mutation" {
  let root = @fs.tmpdir(prefix="mooncmd-mv-link-backup")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  let referent = @fsops.join(root, "referent")
  @fs.write_file(source, b"new\n")
  @fs.write_file(referent, b"untouched\n")
  let referent_path = @fs.realpath(referent)
  @fs.symlink(target=referent_path, destination, force_symlink=true)
  let options = { ..link_move_options(), backup: @fsops.SimpleBackup, }
  if unverified_windows_link_rename() {
    try move_one(source, destination, options) catch {
      @fsops.FsOpError(message) =>
        assert_eq(
          message, "unsupported capability: Windows Wasm symlink/junction rename requires a verified host fix",
        )
      error => raise error
    } noraise {
      _ =>
        fail("unverified backup must fail before moving the destination link")
    }
    assert_eq(@fs.read_file(source).binary(), b"new\n")
    assert_true(@fs.kind(destination, follow_symlink=false) is SymLink)
    assert_eq(@fs.realpath(destination), referent_path)
    assert_true(@fsops.kind_if_exists(destination + "~") is None)
  } else {
    assert_true(move_one(source, destination, options) is Moved)
    assert_true(@fsops.kind_if_exists(source) is None)
    assert_eq(@fs.read_file(destination).binary(), b"new\n")
    assert_true(@fs.kind(destination + "~", follow_symlink=false) is SymLink)
    assert_eq(@fs.realpath(destination + "~"), referent_path)
  }
  assert_eq(@fs.read_file(referent).binary(), b"untouched\n")
}

///|
async test "mv no-clobber and update-none leave a source link and its referent unchanged" {
  let root = @fs.tmpdir(prefix="mooncmd-mv-link-skip")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  let referent = @fsops.join(root, "referent")
  @fs.write_file(destination, b"keep destination\n")
  @fs.write_file(referent, b"keep referent\n")
  let referent_path = @fs.realpath(referent)
  @fs.symlink(target=referent_path, source, force_symlink=true)
  let options = link_move_options()
  for
    selected in [
      { ..options, no_clobber: true, },
      { ..options, update: @fsops.UpdateNone, },
    ] {
    assert_true(move_one(source, destination, selected) is Skipped)
    assert_true(@fs.kind(source, follow_symlink=false) is SymLink)
    assert_eq(@fs.realpath(source), referent_path)
    assert_eq(@fs.read_file(referent).binary(), b"keep referent\n")
    assert_eq(@fs.read_file(destination).binary(), b"keep destination\n")
    assert_true(@fsops.kind_if_exists(destination + "~") is None)
  }
}

///|
async test "mv replacing an existing target reads the dangling source link timestamp" {
  let root = @fs.tmpdir(prefix="mooncmd-mv-dangling")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  for backup in [@fsops.NoBackup, @fsops.SimpleBackup] {
    let directory = @fsops.join(
      root,
      if backup == @fsops.NoBackup {
        "replace"
      } else {
        "backup"
      },
    )
    @fs.mkdir(directory)
    let source = @fsops.join(directory, "source")
    let destination = @fsops.join(directory, "destination")
    let missing = @fsops.join(@fs.realpath(directory), "missing")
    @fs.symlink(target=missing, source, force_symlink=true)
    @fs.write_file(destination, b"old target\n")
    let options = { ..link_move_options(), backup, }
    if unverified_windows_link_rename() {
      try move_one(source, destination, options) catch {
        @fsops.FsOpError(message) =>
          assert_true(message.contains("Windows Wasm"))
        error => raise error
      } noraise {
        _ => fail("unverified dangling link rename must reject")
      }
      assert_true(@fs.kind(source, follow_symlink=false) is SymLink)
      assert_eq(@fs.read_file(destination).binary(), b"old target\n")
      assert_true(@fsops.kind_if_exists(destination + "~") is None)
    } else {
      assert_true(move_one(source, destination, options) is Moved)
      assert_true(@fsops.kind_if_exists(source) is None)
      assert_true(@fs.kind(destination, follow_symlink=false) is SymLink)
      if backup == @fsops.SimpleBackup {
        assert_eq(@fs.read_file(destination + "~").binary(), b"old target\n")
      } else {
        assert_true(@fsops.kind_if_exists(destination + "~") is None)
      }
    }
    assert_true(@fsops.kind_if_exists(missing) is None)
  }
}

///|
async test "mv restores a completed backup after an injected rename failure" {
  let root = @fs.tmpdir(prefix="mooncmd-mv-rollback")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  @fs.write_file(source, b"new source\n")
  @fs.write_file(destination, b"old target\n")
  let mut reached_commit = false
  try
    move_one(
      source,
      destination,
      { ..link_move_options(), backup: @fsops.SimpleBackup, },
      rename=(from, to, replace) => {
        reached_commit = true
        assert_eq(from, source)
        assert_eq(to, destination)
        assert_false(replace)
        assert_true(@fsops.kind_if_exists(destination) is None)
        assert_eq(@fs.read_file(destination + "~").binary(), b"old target\n")
        raise @fsops.FsOpError("injected rename failure after backup")
      },
    )
  catch {
    @fsops.FsOpError(message) =>
      assert_eq(message, "injected rename failure after backup")
    error => raise error
  } noraise {
    _ => fail("the injected commit must fail")
  }
  assert_true(reached_commit)
  assert_eq(@fs.read_file(source).binary(), b"new source\n")
  assert_eq(@fs.read_file(destination).binary(), b"old target\n")
  assert_true(@fsops.kind_if_exists(destination + "~") is None)
}

///|
async fn prepare_windows_rollback_link(
  directory : String,
  name : String,
  kind : String,
) -> String {
  let referent = @fsops.join(directory, name + "-referent")
  match kind {
    "file" => @fs.write_file(referent, "\{name} referent must remain\n")
    "directory" | "junction" => {
      @fs.mkdir(referent)
      @fs.write_file(referent + "/payload", "\{name} referent must remain\n")
    }
    "dangling" => ()
    _ => fail("unknown rollback link kind")
  }
  @fs.symlink(
    target=referent,
    @fsops.join(directory, name),
    force_symlink=kind != "junction",
  )
  referent
}

///|
async fn assert_windows_rollback_link(
  path : String,
  kind : String,
  referent : String,
  name : String,
) -> Unit {
  assert_true(@fs.kind(path, follow_symlink=false) is SymLink)
  assert_windows_link_type(
    path,
    if kind == "junction" {
      "Junction"
    } else {
      "SymbolicLink"
    },
    target=referent,
  )
  match kind {
    "dangling" => assert_true(@fsops.kind_if_exists(referent) is None)
    "file" =>
      assert_eq(
        @fs.read_file(referent).text(),
        "\{name} referent must remain\n",
      )
    "directory" | "junction" => {
      assert_true(@fs.kind(referent, follow_symlink=false) is Directory)
      assert_eq(
        @fs.read_file(referent + "/payload").text(),
        "\{name} referent must remain\n",
      )
    }
    _ => fail("unknown rollback link kind")
  }
}

///|
async test "mv restores Windows link backups after injected commit failure or rejects before mutation" {
  if @async.platform is Windows {
    let root = @fs.tmpdir(prefix="mooncmd-mv-link-rollback")
    defer (@fs.rmdir(root, recursive=true) catch { _ => () })
    for kind in ["file", "directory", "dangling", "junction"] {
      for source_link in [false, true] {
        let directory = @fsops.join(
          root,
          kind + (if source_link { "-link-source" } else { "-regular-source" }),
        )
        @fs.mkdir(directory)
        let directory = @fs.realpath(directory)
        let source = @fsops.join(directory, "source")
        let destination = @fsops.join(directory, "destination")
        let source_referent = if source_link {
          Some(prepare_windows_rollback_link(directory, "source", kind))
        } else {
          @fs.write_file(source, b"new regular source\n")
          None
        }
        let destination_referent = prepare_windows_rollback_link(
          directory, "destination", kind,
        )
        assert_windows_rollback_link(
          destination, kind, destination_referent, "destination",
        )
        if source_referent is Some(referent) {
          assert_windows_rollback_link(source, kind, referent, "source")
        }
        let mut reached_commit = false
        try
          move_one(
            source,
            destination,
            { ..link_move_options(), backup: @fsops.SimpleBackup, },
            rename=(from, to, replace) => {
              reached_commit = true
              assert_eq(from, source)
              assert_eq(to, destination)
              assert_false(replace)
              assert_true(@fsops.kind_if_exists(destination) is None)
              // Observe the real completed backup before injecting commit failure.
              assert_windows_rollback_link(
                destination + "~",
                kind,
                destination_referent,
                "destination",
              )
              raise @fsops.FsOpError(
                "injected link commit failure after backup",
              )
            },
          )
        catch {
          @fsops.FsOpError(message) =>
            assert_eq(
              message,
              if unverified_windows_link_rename() {
                "unsupported capability: Windows Wasm symlink/junction rename requires a verified host fix"
              } else {
                "injected link commit failure after backup"
              },
            )
          error => raise error
        } noraise {
          _ => fail("the link commit or unverified rename must fail")
        }
        assert_eq(reached_commit, !unverified_windows_link_rename())
        assert_windows_rollback_link(
          destination, kind, destination_referent, "destination",
        )
        if source_referent is Some(referent) {
          assert_windows_rollback_link(source, kind, referent, "source")
        } else {
          assert_true(@fs.kind(source, follow_symlink=false) is Regular)
          assert_eq(@fs.read_file(source).binary(), b"new regular source\n")
        }
        assert_true(@fsops.kind_if_exists(destination + "~") is None)
        let entries = @fs.readdir(directory, sort=true)
        let expected = ["destination", "source"]
        if kind != "dangling" {
          expected.push("destination-referent")
          if source_link {
            expected.push("source-referent")
          }
        }
        expected.sort()
        assert_eq(entries, expected)
      }
    }
  }
}
