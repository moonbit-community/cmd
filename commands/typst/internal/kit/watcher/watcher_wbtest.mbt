// Tests of the watcher: the watched set, the batching of `wait` on
// synthetic events, and `wait` on real files (through `@fs.Watcher`).

///|
/// Creates an empty directory for a test and returns its path.
async fn scratch(name : String) -> String {
  let path = "_build/kit_watcher_test/\{name}"
  @fs.rmdir(path, recursive=true) catch {
    _ => ()
  }
  @fs.mkdir(path, recursive=true)
  path
}

///|
/// Writes a file in place (created if it does not exist).
async fn write(path : String, content : String) -> Unit {
  @fs.write_file(path, content)
}

///|
/// Whether `wait` returns within the given time.
async fn returns_within(watcher : Watcher, ms : Int32) -> Bool {
  @async.with_timeout_opt(ms, () => watcher.wait()) is Some(_)
}

///|
/// The sorted keys of a map, joined.
fn[V] keys(map : Map[String, V]) -> String {
  let keys = map.keys().to_array()
  keys.sort()
  keys.join(" ")
}

///|
/// The sorted watched paths of the underlying watcher, pending ones in
/// parentheses.
fn registered(watcher : Watcher) -> String {
  let paths = []
  for path, watch in watcher.watcher.paths {
    paths.push(
      match watch {
        Pending => "(\{path})"
        Watched(_) => path
      },
    )
  }
  paths.sort()
  paths.join(" ")
}

///|
/// Sends an event to a watcher's channel, as its event sources do.
async fn inject(watcher : Watcher, kind : EventKind, path : String) -> Unit {
  watcher.watcher.tx.put(Ok({ kind, paths: [path], }))
}

///|
/// The running watchers of the underlying watcher: their directories (below
/// the tests' directory) with the entries they follow.
fn running(watcher : Watcher) -> String {
  let lines = []
  for dir, running in watcher.watcher.dirs {
    let entries = running.names.keys().to_array()
    entries.sort()
    let dir = dir.strip_prefix("_build/kit_watcher_test/").unwrap_or(dir)
    lines.push("\{dir}: \{entries.join(" ")}")
  }
  // (Shorter lines first: the order of strings.)
  lines.sort()
  lines.join("; ")
}

///|
async test "update watches exactly the listed files" {
  @async.with_task_group(group => {
    let dir = scratch("update")
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    let c = "\{dir}/c.typ"
    let d = "\{dir}/sub/d.typ"
    write(a, "a")
    write(b, "b")
    @fs.mkdir("\{dir}/sub")
    write(d, "d")
    let watcher = Watcher::new(None, group)
    watcher.update([a, b, c, d])
    // Existing files are watched, the others are polled for.
    inspect(
      keys(watcher.watched),
      content="_build/kit_watcher_test/update/a.typ _build/kit_watcher_test/update/b.typ _build/kit_watcher_test/update/sub/d.typ",
    )
    inspect(
      keys(watcher.missing),
      content="_build/kit_watcher_test/update/c.typ",
    )
    inspect(
      registered(watcher),
      content="_build/kit_watcher_test/update/a.typ _build/kit_watcher_test/update/b.typ _build/kit_watcher_test/update/sub/d.typ",
    )
    // One watcher per directory.
    inspect(running(watcher), content="update/sub: d.typ; update: a.typ b.typ")
    guard watcher.watcher.dirs.get(dir) is Some(first) else {
      fail("no watcher")
    }
    guard watcher.watcher.dirs.get("\{dir}/sub") is Some(sub) else {
      fail("no watcher")
    }

    // A file that is no longer listed is unwatched, a new one is watched,
    // a missing one is not missing any more. The directory of the new one
    // has a new watcher for its files (the old one cannot take another),
    // the other directory keeps its watcher.
    write(c, "c")
    watcher.update([b, c, d])
    inspect(
      keys(watcher.watched),
      content="_build/kit_watcher_test/update/b.typ _build/kit_watcher_test/update/c.typ _build/kit_watcher_test/update/sub/d.typ",
    )
    inspect(keys(watcher.missing), content="")
    inspect(
      registered(watcher),
      content="_build/kit_watcher_test/update/b.typ _build/kit_watcher_test/update/c.typ _build/kit_watcher_test/update/sub/d.typ",
    )
    inspect(running(watcher), content="update/sub: d.typ; update: b.typ c.typ")
    guard watcher.watcher.dirs.get(dir) is Some(second) else {
      fail("no watcher")
    }
    inspect(physical_equal(first, second), content="false")
    guard watcher.watcher.dirs.get("\{dir}/sub") is Some(still) else {
      fail("no watcher")
    }
    inspect(physical_equal(sub, still), content="true")
    inspect(keys(watcher.watcher.retired), content="")

    // The same list again changes nothing.
    watcher.update([b, c, d])
    guard watcher.watcher.dirs.get(dir) is Some(third) else {
      fail("no watcher")
    }
    inspect(physical_equal(second, third), content="true")

    // A directory without listed files loses its watcher.
    watcher.update([b])
    inspect(running(watcher), content="update: b.typ c.typ")
    inspect(registered(watcher), content="_build/kit_watcher_test/update/b.typ")

    // Nothing is listed: nothing is watched.
    watcher.update([])
    inspect(keys(watcher.watched), content="")
    inspect(registered(watcher), content="")
    inspect(running(watcher), content="")
    inspect(watcher.watcher.idle.length(), content="0")
  })
}

///|
async test "wait: only a change of a watched file ends it" {
  @async.with_task_group(group => {
    let dir = scratch("change")
    let a = "\{dir}/a.typ"
    let other = "\{dir}/other.typ"
    write(a, "a")
    write(other, "other")
    let watcher = Watcher::new(None, group)
    watcher.update([a])
    write(other, "changed")
    write("\{dir}/new.typ", "new")
    inspect(returns_within(watcher, 600), content="false")
    write(a, "changed")
    inspect(returns_within(watcher, 5000), content="true")
    // And again, without an update in between.
    write(a, "changed again")
    inspect(returns_within(watcher, 5000), content="true")
  })
}

///|
async test "wait: a file that is replaced stays watched" {
  @async.with_task_group(group => {
    let dir = scratch("replace")
    let a = "\{dir}/a.typ"
    write(a, "a")
    let watcher = Watcher::new(None, group)
    watcher.update([a])

    // An editor that writes a temporary file and renames it over the
    // original.
    write("\{dir}/a.typ.tmp", "second")
    @fs.rename("\{dir}/a.typ.tmp", a, replace=true)
    inspect(returns_within(watcher, 5000), content="true")
    // The removal was reported, so the path is watched anew.
    inspect(keys(watcher.watched), content="")
    watcher.update([a])
    inspect(
      keys(watcher.watched),
      content="_build/kit_watcher_test/replace/a.typ",
    )
    write(a, "third")
    inspect(returns_within(watcher, 5000), content="true")

    // An editor that moves the original away and writes a new file.
    watcher.update([a])
    @fs.rename(a, "\{dir}/a.typ~")
    write(a, "fourth")
    inspect(returns_within(watcher, 5000), content="true")
    watcher.update([a])
    write(a, "fifth")
    inspect(returns_within(watcher, 5000), content="true")
  })
}

///|
async test "wait: changes between an unwatch and the next update are seen" {
  @async.with_task_group(group => {
    let dir = scratch("gap")
    let a = "\{dir}/a.typ"
    write(a, "a")
    let watcher = Watcher::new(None, group)
    watcher.update([a])
    @fs.remove(a)
    inspect(returns_within(watcher, 5000), content="true")
    inspect(keys(watcher.watched), content="")
    // What a compilation that fails would not see: the file comes back
    // before the watcher is updated.
    write(a, "back")
    watcher.update([a])
    inspect(keys(watcher.missing), content="")
    inspect(returns_within(watcher, 5000), content="true")
  })
}

///|
async test "wait: polls for missing files" {
  @async.with_task_group(group => {
    let dir = scratch("missing")
    let a = "\{dir}/sub/a.typ"
    let watcher = Watcher::new(None, group)
    watcher.update([a])
    inspect(
      keys(watcher.missing),
      content="_build/kit_watcher_test/missing/sub/a.typ",
    )
    inspect(registered(watcher), content="")
    inspect(returns_within(watcher, 900), content="false")
    @fs.mkdir("\{dir}/sub")
    write(a, "a")
    inspect(returns_within(watcher, 5000), content="true")
  })
}

///|
async test "wait: the output file is ignored" {
  @async.with_task_group(group => {
    let dir = scratch("output")
    let a = "\{dir}/a.typ"
    let out = "\{dir}/a.svg"
    write(a, "a")
    write(out, "<svg/>")
    // The output under another spelling of its path.
    let watcher = Watcher::new(Some("\{dir}/./a.svg"), group)
    watcher.update([a, out])
    write(out, "<svg></svg>")
    inspect(returns_within(watcher, 600), content="false")
    write(a, "changed")
    inspect(returns_within(watcher, 5000), content="true")
  })
}

///|
async test "wait: a directory that is removed and created again" {
  @async.with_task_group(group => {
    let dir = scratch("directory")
    let sub = "\{dir}/figures"
    let a = "\{sub}/a.svg"
    let b = "\{sub}/b.svg"
    @fs.mkdir(sub)
    write(a, "a")
    write(b, "b")
    let watcher = Watcher::new(None, group)
    watcher.update([a, b])
    @fs.rmdir(sub, recursive=true)
    @fs.mkdir(sub)
    write(a, "a2")
    write(b, "b2")
    inspect(returns_within(watcher, 5000), content="true")
    // Both removals were reported (in this batch or, if it was cut short,
    // in the next), so both files are watched anew in the new directory.
    watcher.update([a, b])
    ignore(returns_within(watcher, 600))
    watcher.update([a, b])
    write(b, "b3")
    inspect(returns_within(watcher, 5000), content="true")
  })
}

///|
async test "wait: batches events" {
  @async.with_task_group(group => {
    let watcher = Watcher::new(None, group)
    // Without events it does not return.
    inspect(returns_within(watcher, 300), content="false")

    // One event: `wait` returns once nothing followed for `BATCH_TIMEOUT`.
    let start = @async.now()
    inject(watcher, Modify(Data(Any)), "a")
    watcher.wait()
    let elapsed = @async.now() - start
    inspect(elapsed >= 90L && elapsed < 2000L, content="true")

    // Events that keep coming are bunched up, but not for longer than
    // `STARVE_TIMEOUT`.
    group.spawn_bg(no_wait=true, () => {
      for _ in 0..<60 {
        inject(watcher, Modify(Data(Any)), "a")
        @async.sleep(50)
      }
    })
    @async.sleep(10)
    let start = @async.now()
    watcher.wait()
    let elapsed = @async.now() - start
    // (The events keep coming for three seconds.)
    inspect(elapsed >= 450L && elapsed < 2500L, content="true")
  })
}

///|
async test "wait: which events are relevant" {
  @async.with_task_group(group => {
    let dir = scratch("relevant")
    let out = "\{dir}/out.pdf"
    write(out, "%PDF")
    let watcher = Watcher::new(Some(out), group)

    // Access and metadata changes are not.
    inject(watcher, Access(Open(Any)), "a")
    inject(watcher, Modify(Metadata(WriteTime)), "a")
    inject(watcher, Other, "a")
    inspect(returns_within(watcher, 400), content="false")

    // Neither are events of the output file alone.
    inject(watcher, Modify(Data(Any)), out)
    inspect(returns_within(watcher, 400), content="false")
    watcher.watcher.tx.put(Ok({ kind: Modify(Name(Both)), paths: [out, "a"], }))
    inspect(returns_within(watcher, 2000), content="true")

    // A removal or a rename away forgets the path, so that the next
    // update watches it again.
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    write(a, "a")
    write(b, "b")
    watcher.update([a, b])
    inject(watcher, Remove(File), a)
    inspect(returns_within(watcher, 2000), content="true")
    inspect(
      keys(watcher.watched),
      content="_build/kit_watcher_test/relevant/b.typ",
    )
    inspect(
      registered(watcher),
      content="_build/kit_watcher_test/relevant/b.typ",
    )
    inspect(
      keys(watcher.watcher.retired),
      content="_build/kit_watcher_test/relevant/a.typ",
    )
    inject(watcher, Modify(Name(From)), b)
    inspect(returns_within(watcher, 2000), content="true")
    inspect(keys(watcher.watched), content="")
    watcher.update([a, b])
    inspect(
      registered(watcher),
      content="_build/kit_watcher_test/relevant/a.typ _build/kit_watcher_test/relevant/b.typ",
    )
    inspect(keys(watcher.watcher.retired), content="")
    // Other removals do not.
    inject(watcher, Remove(Any), a)
    inject(watcher, Modify(Name(To)), b)
    inspect(returns_within(watcher, 2000), content="true")
    inspect(
      keys(watcher.watched),
      content="_build/kit_watcher_test/relevant/a.typ _build/kit_watcher_test/relevant/b.typ",
    )
  })
}

///|
async test "wait: an error of the watcher" {
  @async.with_task_group(group => {
    let watcher = Watcher::new(None, group)
    watcher.watcher.tx.put(Err(NotifyError("boom", path=None)))
    try watcher.wait() catch {
      @kit.StrError(message) =>
        inspect(message, content="failed to watch dependencies (boom)")
    } noraise {
      _ => fail("expected an error")
    }
  })
}

///|
async test "update: a path that cannot be watched" {
  @async.with_task_group(group => {
    let watcher = Watcher::new(None, group)
    // The root directory has no parent to watch it from.
    try watcher.update(["/"]) catch {
      @kit.StrError(message) =>
        inspect(
          message,
          content="failed to watch \"/\" (No path was found. about [\"/\"])",
        )
    } noraise {
      _ => fail("expected an error")
    }
  })
}

///|
test "is_relevant_event_kind" {
  let kinds : Array[(String, EventKind)] = [
    ("any", Any),
    ("access", Access(Any)),
    ("access read", Access(Read)),
    ("access close", Access(Close(Write))),
    ("create", Create(Any)),
    ("create file", Create(File)),
    ("create folder", Create(Folder)),
    ("modify", Modify(Any)),
    ("modify data", Modify(Data(Any))),
    ("modify size", Modify(Data(Size))),
    ("modify content", Modify(Data(Content))),
    ("modify metadata", Modify(Metadata(Any))),
    ("modify permissions", Modify(Metadata(Permissions))),
    ("modify name", Modify(Name(Any))),
    ("modify name from", Modify(Name(From))),
    ("modify name to", Modify(Name(To))),
    ("modify name both", Modify(Name(Both))),
    ("modify other", Modify(Other)),
    ("remove", Remove(Any)),
    ("remove file", Remove(File)),
    ("remove folder", Remove(Folder)),
    ("other", Other),
  ]
  let relevant = []
  let irrelevant = []
  for entry in kinds {
    if is_relevant_event_kind(entry.1) {
      relevant.push(entry.0)
    } else {
      irrelevant.push(entry.0)
    }
  }
  inspect(
    relevant.join(", "),
    content="any, create, create file, create folder, modify, modify data, modify size, modify content, modify name, modify name from, modify name to, modify name both, remove, remove file, remove folder",
  )
  inspect(
    irrelevant.join(", "),
    content="access, access read, access close, modify metadata, modify permissions, modify other, other",
  )
}

///|
async test "is_same_file" {
  let dir = scratch("same")
  let a = "\{dir}/a.typ"
  let b = "\{dir}/b.typ"
  write(a, "a")
  write(b, "b")
  inspect(is_same_file(a, a), content="true")
  inspect(is_same_file(a, "\{dir}/./a.typ"), content="true")
  inspect(is_same_file(a, b), content="false")
  // Another name of the file (where a link can be told).
  @fs.symlink(target="a.typ", "\{dir}/link.typ")
  if @platform.lstat_kind("\{dir}/link.typ") is Symlink {
    inspect(is_same_file(a, "\{dir}/link.typ"), content="true")
    inspect(is_same_file(b, "\{dir}/link.typ"), content="false")
  }
  // A file that does not exist is the same as none, not even as itself.
  inspect(is_same_file(a, "\{dir}/c.typ"), content="false")
  inspect(is_same_file("\{dir}/c.typ", "\{dir}/c.typ"), content="false")
}
