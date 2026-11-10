///|
async fn filesystem_windows_observer(
  observation_path : String,
  observations : Array[Json],
  phase : String,
  program : String,
  args : Array[String],
  extra_env~ : Map[String, String] = Map([]),
) -> String {
  let completed = @harness.run_with_deadline(
    program,
    args,
    15000,
    stdin=b"",
    extra_env~,
  )
  let stdout = @harness.scenario_text(completed.output.stdout)
  filesystem_record(observation_path, observations, {
    "phase": phase,
    "program": program,
    "args": args,
    "status": completed.output.status,
    "stdout": stdout,
    "stderr": @harness.scenario_text(completed.output.stderr),
    "timed_out": completed.timed_out,
    "cleanup_error": completed.cleanup_error,
  })
  guard !completed.timed_out &&
    completed.cleanup_error is None &&
    completed.output.status == 0 &&
    completed.output.stderr == b"" else {
    fail("required Windows observer infrastructure failed: " + phase)
  }
  stdout
}

///|
async fn filesystem_windows_id(
  path : String,
  observation_path : String,
  observations : Array[Json],
) -> String {
  let raw = filesystem_windows_observer(
    observation_path,
    observations,
    "file-id",
    "fsutil.exe",
    ["file", "queryfileid", path],
  )
  // Ignore localized prose, but require one complete 128-bit hexadecimal ID.
  let pieces = raw.split("0x").collect()
  guard pieces.length() == 2 else {
    fail("Windows file ID observer returned no unique ID")
  }
  let id = pieces[1].trim().to_owned().to_lower()
  guard id.length() == 32 &&
    id.iter().all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) else {
    fail("Windows file ID observer returned invalid hexadecimal identity")
  }
  id
}

///|
fn filesystem_native_unix_time(value : (Int64, Int32)) -> (Int64, Int32) {
  // async 0.22.9 Native returns Windows FILETIME seconds since 1601. The
  // pinned Wasm host already returns Unix time; this is an observer-only fix.
  let (seconds, nanos) = value
  (
    if @async.platform is Windows {
      seconds - 11644473600L
    } else {
      seconds
    },
    nanos,
  )
}

///|
async fn filesystem_windows_set_time(
  path : String,
  accessed : Int64,
  modified : Int64,
  observation_path : String,
  observations : Array[Json],
  births? : Array[Int64],
) -> Unit {
  let clock_before = @env.now().reinterpret_as_int64()
  let raw = filesystem_windows_observer(
    observation_path,
    observations,
    "timestamp-setup",
    "powershell.exe",
    [
      "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $p=$env:CMD_F29_PATH; $a=[DateTimeOffset]::FromUnixTimeSeconds([long]$env:CMD_F29_ATIME).UtcDateTime; $m=[DateTimeOffset]::FromUnixTimeSeconds([long]$env:CMD_F29_MTIME).UtcDateTime; [IO.File]::SetLastAccessTimeUtc($p,$a); [IO.File]::SetLastWriteTimeUtc($p,$m); [pscustomobject]@{path=$p; atime=([DateTimeOffset][IO.File]::GetLastAccessTimeUtc($p)).ToUnixTimeSeconds().ToString(); mtime=([DateTimeOffset][IO.File]::GetLastWriteTimeUtc($p)).ToUnixTimeSeconds().ToString(); atime_ticks=[IO.File]::GetLastAccessTimeUtc($p).Ticks.ToString(); mtime_ticks=[IO.File]::GetLastWriteTimeUtc($p).Ticks.ToString(); creation_ticks=[IO.File]::GetCreationTimeUtc($p).Ticks.ToString(); powershell=$PSVersionTable.PSVersion.ToString(); os=[Environment]::OSVersion.VersionString} | ConvertTo-Json -Compress",
    ],
    extra_env={
      "CMD_F29_PATH": path,
      "CMD_F29_ATIME": accessed.to_string(),
      "CMD_F29_MTIME": modified.to_string(),
    },
  )
  guard @json.parse(raw) is { "atime": String(a), "mtime": String(m), .. } &&
    a == accessed.to_string() &&
    m == modified.to_string() else {
    fail("Windows timestamp setup did not produce the requested values")
  }
  let actual_a = @fs.atime(path)
  let actual_m = @fs.mtime(path)
  let actual_c = @fs.ctime(path)
  let unix_a = filesystem_native_unix_time(actual_a)
  let unix_m = filesystem_native_unix_time(actual_m)
  let unix_c = filesystem_native_unix_time(actual_c)
  let clock_after = @env.now().reinterpret_as_int64()
  filesystem_record(observation_path, observations, {
    "phase": "timestamp-native-precondition",
    "path": path,
    "atime": actual_a,
    "mtime": actual_m,
    "ctime": actual_c,
    "native_epoch": "1601-01-01 UTC; seconds and nanoseconds",
    "unix_atime": unix_a,
    "unix_mtime": unix_m,
    "unix_ctime": unix_c,
    "clock_before_ms": clock_before.to_string(),
    "clock_after_ms": clock_after.to_string(),
    "ctime_source": "released public fs.ctime reads status ChangeTime; CreationTime is not substituted",
  })
  assert_eq(unix_a, (accessed, 0))
  assert_eq(unix_m, (modified, 0))
  assert_true(unix_c.1 >= 0 && unix_c.1 < 1000000000)
  assert_true(
    clock_after >= clock_before &&
    unix_c.0 >= clock_before / 1000L &&
    unix_c.0 <= clock_after / 1000L,
  )
  if births is Some(values) {
    guard @json.parse(raw) is { "creation_ticks": String(ticks), .. } else {
      fail("Windows creation-time control observation missing")
    }
    values.push(@string.parse_int64(ticks))
  }
}

///|
async fn filesystem_windows_snapshot(
  work : String,
  observation_path : String,
  observations : Array[Json],
) -> Array[@harness.SnapshotEntry] {
  let entries = @harness.snapshot(
    work,
    observe=["atime", "mtime", "ctime", "symlink-target"],
    content=false,
    preserve_identity=true,
  )
  for entry in entries {
    if entry.kind == "file" {
      entry.metadata["identity"] = filesystem_windows_id(
        work + "/" + entry.path,
        observation_path,
        observations,
      )
      let raw = filesystem_windows_observer(
        observation_path,
        observations,
        "attributes-acl",
        "powershell.exe",
        [
          "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $p=$env:CMD_F29_PATH; $i=Get-Item -LiteralPath $p -Force; [pscustomobject]@{attributes=$i.Attributes.ToString(); sddl=(Get-Acl -LiteralPath $p).Sddl; volume=[IO.Path]::GetPathRoot($i.FullName)} | ConvertTo-Json -Compress",
        ],
        extra_env={ "CMD_F29_PATH": work + "/" + entry.path },
      )
      guard @json.parse(raw)
        is {
          "attributes": String(attributes),
          "sddl": String(sddl),
          "volume": String(volume),
          ..
        } &&
        sddl != "" &&
        volume != "" else {
        fail("Windows ACL/volume observation incomplete")
      }
      entry.metadata["windows-attributes"] = attributes
      entry.metadata["windows-sddl"] = sddl
      entry.metadata["windows-volume"] = volume.to_lower()
    }
  }
  entries
}

///|
async fn filesystem_windows_scenario(
  root : String,
  work : String,
  observation_path : String,
) -> Unit {
  guard @async.platform is Windows else {
    fail("Windows observation fixture required")
  }
  guard !@fs.exists(observation_path) else {
    fail("preserve previous Windows observations")
  }
  let observations : Array[Json] = []
  let volume = filesystem_windows_observer(
    observation_path,
    observations,
    "volume-precondition",
    "powershell.exe",
    [
      "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); $root=[IO.Path]::GetPathRoot($env:CMD_F29_PATH); $drive=[IO.DriveInfo]::new($root); [pscustomobject]@{root=$root; filesystem=$drive.DriveFormat; ready=$drive.IsReady} | ConvertTo-Json -Compress",
    ],
    extra_env={ "CMD_F29_PATH": work },
  )
  guard @json.parse(volume)
    is { "filesystem": String("NTFS"), "ready": True, .. } else {
    fail(
      "Windows identity infrastructure requires the observed NTFS fixture volume",
    )
  }
  // This also exercises all a/c/m source/reference selectors using distinct
  // actual ChangeTime values; the same-entry controls include strict ties.
  metadata_selector_matrix(root, work, observation_path, observations)
  @fs.mkdir(work + "/identity")
  let identity = work + "/identity"
  @fs.write_file(identity + "/source", "retained")
  @fs.write_file(identity + "/independent", "retained")
  ignore(
    filesystem_windows_observer(
      observation_path,
      observations,
      "hardlink-setup",
      "fsutil.exe",
      ["hardlink", "create", identity + "/alias", identity + "/source"],
    ),
  )
  let links_before = filesystem_windows_observer(
    observation_path,
    observations,
    "hardlink-list-before",
    "fsutil.exe",
    ["hardlink", "list", identity + "/source"],
  )
  let names = links_before
    .replace_all(old="\\", new="/")
    .split("\n")
    .map(line => line.trim().to_owned().to_lower())
    .filter(line => line != "")
    .collect()
  assert_eq(names.length(), 2)
  assert_true(names.any(name => name.has_suffix("/identity/source")))
  assert_true(names.any(name => name.has_suffix("/identity/alias")))
  filesystem_windows_set_time(
    identity + "/source",
    946684800L,
    1577836800L,
    observation_path,
    observations,
  )
  filesystem_windows_set_time(
    identity + "/independent",
    946684800L,
    1577836800L,
    observation_path,
    observations,
  )
  let before = filesystem_windows_snapshot(
    identity, observation_path, observations,
  )
  let ids : Map[String, String] = Map([])
  for entry in before {
    ids[entry.path] = entry.metadata["windows-volume"] +
      ":" +
      entry.metadata["identity"]
  }
  assert_eq(ids["source"], ids["alias"])
  assert_true(ids["source"] != ids["independent"])
  for name in ["source", "alias", "independent"] {
    filesystem_predicate_control(
      root,
      identity,
      observation_path,
      observations,
      "test",
      ["-s", name],
      0,
      "",
    )
    filesystem_predicate_control(
      root,
      identity,
      observation_path,
      observations,
      "test",
      ["-N", name],
      0,
      "",
    )
    filesystem_predicate_control(
      root,
      identity,
      observation_path,
      observations,
      "find",
      [name, "-type", "f", "-size", "8c"],
      0,
      name + "\n",
    )
  }
  let after = filesystem_windows_snapshot(
    identity, observation_path, observations,
  )
  filesystem_record(observation_path, observations, {
    "phase": "identity-preserved",
    "before": before.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
    "after": after.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
  })
  assert_true(@harness.snapshots_equal(before, after))
  let links_after = filesystem_windows_observer(
    observation_path,
    observations,
    "hardlink-list-after",
    "fsutil.exe",
    ["hardlink", "list", identity + "/source"],
  )
  assert_eq(links_after, links_before)
  for name in ["source", "alias", "independent"] {
    assert_eq(@fs.read_file(identity + "/" + name).text(), "retained")
  }
  @fs.mkdir(work + "/times")
  let times = work + "/times"
  for
    (name, access, modified) in [
      ("old", 946684800L, 946684800L),
      ("new", 946684800L, 1577836800L),
      ("equal", 1577836800L, 1577836800L),
      ("access-future", 4070908800L, 1577836800L),
      ("future", 4070908800L, 4070908800L),
    ] {
    @fs.write_file(times + "/" + name, name)
    filesystem_windows_set_time(
      times + "/" + name,
      access,
      modified,
      observation_path,
      observations,
    )
  }
  @fs.symlink(
    times + "/link",
    target=@fs.realpath(times + "/new"),
    force_symlink=true,
  )
  assert_true(@fs.kind(times + "/link", follow_symlink=false) is SymLink)
  assert_eq(@fs.realpath(times + "/link"), @fs.realpath(times + "/new"))
  @fs.mkdir(times + "/directory")
  @fs.write_file(times + "/directory/sentinel", "directory retained")
  for (name, symbolic) in [("directory-link", true), ("junction", false)] {
    @fs.symlink(
      times + "/" + name,
      target=@fs.realpath(times + "/directory"),
      force_symlink=symbolic,
    )
    assert_true(@fs.kind(times + "/" + name, follow_symlink=false) is SymLink)
    assert_eq(
      @fs.realpath(times + "/" + name),
      @fs.realpath(times + "/directory"),
    )
  }
  let raw_links = filesystem_windows_observer(
    observation_path,
    observations,
    "link-preconditions",
    "powershell.exe",
    [
      "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference='Stop'; [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); @('link','directory-link','junction') | ForEach-Object { $i=Get-Item -LiteralPath ([IO.Path]::Combine($env:CMD_F29_PATH,$_)) -Force; [pscustomobject]@{name=$_; kind=$i.LinkType; target=@($i.Target)[0]} } | ConvertTo-Json -Compress",
    ],
    extra_env={ "CMD_F29_PATH": times },
  )
  guard @json.parse(raw_links) is Array(links) && links.length() == 3 else {
    fail("Windows link observation incomplete")
  }
  for
    (i, name, kind, target) in [
      (0, "link", "SymbolicLink", "new"),
      (1, "directory-link", "SymbolicLink", "directory"),
      (2, "junction", "Junction", "directory"),
    ] {
    guard links[i]
      is {
        "name": String(observed_name),
        "kind": String(observed_kind),
        "target": String(observed_target),
        ..
      } else {
      fail("Windows link fields missing")
    }
    assert_eq(observed_name, name)
    assert_eq(observed_kind, kind)
    assert_eq(@fs.realpath(observed_target), @fs.realpath(times + "/" + target))
  }
  let fresh_start = @env.now().reinterpret_as_int64()
  @fs.write_file(times + "/fresh", "fresh")
  let fresh_raw = @fs.ctime(times + "/fresh")
  let fresh_ctime = filesystem_native_unix_time(fresh_raw)
  let fresh_end = @env.now().reinterpret_as_int64()
  filesystem_record(observation_path, observations, {
    "phase": "windows-age-precondition",
    "raw_ctime": fresh_raw,
    "native_epoch": "1601-01-01 UTC; seconds and nanoseconds",
    "unix_ctime": fresh_ctime,
    "clock_before_ms": fresh_start.to_string(),
    "clock_after_ms": fresh_end.to_string(),
  })
  assert_true(
    fresh_ctime.0 >= fresh_start / 1000L && fresh_ctime.0 <= fresh_end / 1000L,
  )
  assert_true(fresh_ctime.1 >= 0 && fresh_ctime.1 < 1000000000)
  assert_true(
    fresh_start / 1000L > 1577836800L && fresh_end / 1000L < 4070908800L,
  )
  let time_before = @harness.snapshot(
    times,
    observe=["atime", "mtime", "ctime", "symlink-target"],
    content=false,
  )
  @async.sleep(1100)
  let mut age_checks = 0
  for
    (predicate, token, selected) in [
      ("-cmin", "-1", true),
      ("-cmin", "+1", false),
      ("-ctime", "0", true),
      ("-ctime", "+0", false),
    ] {
    filesystem_predicate_control(
      root,
      times,
      observation_path,
      observations,
      "find",
      ["fresh", predicate, token],
      0,
      if selected {
        "fresh\n"
      } else {
        ""
      },
    )
    age_checks += 1
  }
  let age_end = @env.now().reinterpret_as_int64()
  filesystem_record(observation_path, observations, {
    "phase": "windows-age-clock-after",
    "clock_ms": age_end.to_string(),
    "elapsed_ms": (age_end - fresh_start).to_string(),
  })
  guard age_end >= fresh_end &&
    age_end / 1000L > fresh_ctime.0 &&
    age_end / 1000L - fresh_ctime.0 < 50L else {
    fail("Windows age fixture exhausted its minute-window margin")
  }
  for predicate in ["-amin", "-atime", "-mmin", "-mtime"] {
    for
      (name, token, selected) in [
        ("old", "+1", true),
        ("old", "-1", false),
        ("future", "+1", false),
        ("future", "-1", true),
      ] {
      filesystem_predicate_control(
        root,
        times,
        observation_path,
        observations,
        "find",
        [name, predicate, token],
        0,
        if selected {
          name + "\n"
        } else {
          ""
        },
      )
      age_checks += 1
    }
  }
  for
    (name, token, selected) in [
      ("old", "+1", false),
      ("old", "-1", false),
      ("future", "+1", true),
      ("future", "-1", false),
    ] {
    filesystem_predicate_control(
      root,
      times,
      observation_path,
      observations,
      "find",
      [name, "-used", token],
      0,
      if selected {
        name + "\n"
      } else {
        ""
      },
    )
    age_checks += 1
  }
  let mut comparisons = 0
  for
    (args, status) in [
      (["new", "-nt", "old"], 0),
      (["old", "-nt", "new"], 1),
      (["old", "-ot", "new"], 0),
      (["new", "-ot", "old"], 1),
      (["new", "-nt", "equal"], 1),
      (["equal", "-ot", "new"], 1),
      (["new", "-nt", "missing"], 0),
      (["missing", "-nt", "new"], 1),
      (["missing", "-ot", "new"], 0),
      (["new", "-ot", "missing"], 1),
      (["missing", "-nt", "missing"], 1),
      (["missing", "-ot", "missing"], 1),
      (["link", "-nt", "old"], 0),
      (["link", "-nt", "new"], 1),
      (["-N", "new"], 0),
      (["-N", "equal"], 1),
      (["-N", "access-future"], 1),
      (["-N", "link"], 0),
    ] {
    filesystem_predicate_control(
      root, times, observation_path, observations, "test", args, status, "",
    )
    comparisons += 1
  }
  let mut kind_checks = 0
  for name in ["directory-link", "junction"] {
    for (operator, status) in [("-d", 0), ("-L", 0), ("-f", 1)] {
      filesystem_predicate_control(
        root,
        times,
        observation_path,
        observations,
        "test",
        [operator, name],
        status,
        "",
      )
      kind_checks += 1
    }
    for
      (predicate, kind, selected) in [
        ("-type", "l", true),
        ("-type", "d", false),
        ("-xtype", "d", true),
      ] {
      filesystem_predicate_control(
        root,
        times,
        observation_path,
        observations,
        "find",
        [name, "-maxdepth", "0", predicate, kind],
        0,
        if selected {
          name + "\n"
        } else {
          ""
        },
      )
      kind_checks += 1
    }
  }
  for operator in ["-L", "-f"] {
    filesystem_predicate_control(
      root,
      times,
      observation_path,
      observations,
      "test",
      [operator, "link"],
      0,
      "",
    )
    kind_checks += 1
  }
  let time_after = @harness.snapshot(
    times,
    observe=["atime", "mtime", "ctime", "symlink-target"],
    content=false,
  )
  filesystem_record(observation_path, observations, {
    "phase": "time-preserved",
    "native_epoch": "1601-01-01 UTC; seconds and nanoseconds",
    "before": time_before.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
    "after": time_after.map(entry => {
      (
        { "path": entry.path, "kind": entry.kind, "metadata": entry.metadata } :
        Json)
    }),
  })
  assert_true(@harness.snapshots_equal(time_before, time_after))
  for name in ["old", "new", "equal", "access-future", "future", "fresh"] {
    assert_eq(@fs.read_file(times + "/" + name).text(), name)
  }
  assert_eq(
    @fs.read_file(times + "/directory/sentinel").text(),
    "directory retained",
  )

  @harness.assert_observation(
    "find/windows-age-controls",
    "find",
    {
      "comparisons": age_checks,
      "unix_epoch_validated": true,
      "clock_margin_valid": true,
      "metadata_preserved": true,
    },
    {
      "comparisons": 24,
      "unix_epoch_validated": true,
      "clock_margin_valid": true,
      "metadata_preserved": true,
    },
  )
  @harness.assert_observation(
    "test/windows-metadata",
    "test",
    {
      "time_comparisons": comparisons,
      "identity_alias_equal": true,
      "independent_identity_distinct": true,
      "metadata_preserved": true,
    },
    {
      "time_comparisons": 18,
      "identity_alias_equal": true,
      "independent_identity_distinct": true,
      "metadata_preserved": true,
    },
  )
  @harness.assert_observation(
    "find/windows-selectors",
    "find",
    { "comparisons": 144, "metadata_preserved": true },
    { "comparisons": 144, "metadata_preserved": true },
  )
  @harness.assert_observation(
    "test/windows-link-kinds",
    "test",
    {
      "kind_checks": kind_checks,
      "file_link": true,
      "directory_symlink": true,
      "junction": true,
      "targets_preserved": true,
    },
    {
      "kind_checks": 14,
      "file_link": true,
      "directory_symlink": true,
      "junction": true,
      "targets_preserved": true,
    },
  )
}
