// Tests of the bridge from `@fs.Watcher` to notify's interface: which
// events a change is reported as, and for which paths.

///|
fn EventKind::name(self : EventKind) -> String {
  match self {
    Create(Any) => "create"
    Modify(Data(Any)) => "modify"
    Modify(Name(From)) => "rename from"
    Modify(Name(To)) => "rename to"
    Remove(File) => "remove"
    _ => "?"
  }
}

///|
/// The events that arrive until none arrives for a while, in order.
///
/// How a change is reported depends on when the directory was scanned and
/// on the backend, so repetitions of an event are left out, and so is the
/// modification of a file whose removal or creation is reported as well.
async fn drain(rx : Receiver, dir : String) -> String {
  let events : Array[String] = []
  while rx.recv_timeout(Some(if events.is_empty() { 5000 } else { 400 }))
        is Some(event) {
    guard event is Ok(event) else {
      events.push("error")
      continue
    }
    let paths = event.paths.map(path => {
      if path.has_prefix(dir + "/") {
        path[dir.length() + 1:].to_owned()
      } else {
        path
      }
    })
    let event = "\{event.kind.name()} \{paths.join(" ")}"
    if !events.contains(event) {
      events.push(event)
    }
  }
  events
  .filter(event => {
    guard event.strip_prefix("modify ") is Some(path) else { return true }
    !(events.contains("remove \{path}") || events.contains("create \{path}"))
  })
  .join(", ")
}

///|
test "split_path" {
  @debug.debug_inspect(
    split_path("/project/chapters/intro.typ"),
    content=(
      #|Some(("/project/chapters", "intro.typ"))
    ),
  )
  @debug.debug_inspect(
    split_path("main.typ"),
    content=(
      #|Some((".", "main.typ"))
    ),
  )
  @debug.debug_inspect(
    split_path("/main.typ"),
    content=(
      #|Some(("/", "main.typ"))
    ),
  )
  @debug.debug_inspect(
    split_path("figures/"),
    content=(
      #|Some((".", "figures"))
    ),
  )
  @debug.debug_inspect(split_path("/"), content="None")
  @debug.debug_inspect(split_path(".."), content="None")
}

///|
test "name_key" {
  inspect(name_key("Main.TYP"), content="main.typ")
  // Precomposed and decomposed spellings of a name are one entry.
  inspect(name_key("\u{e9}.typ") == name_key("e\u{301}.typ"), content="true")
  inspect(name_key("a.typ") == name_key("b.typ"), content="false")
}

///|
/// The entries that names resolve to among the entries of a directory.
fn resolved(entries : Array[String], names : Array[String]) -> String {
  let wanted : Map[String, Array[String]] = Map([])
  for name in names {
    wanted[name] = ["/dir/\{name}"]
  }
  let lines = []
  for entry, paths in resolve_names_in(entries, wanted) {
    lines.push("\{entry} <- \{paths.join(" ")}")
  }
  lines.sort()
  lines.join("; ")
}

///|
test "resolve_names_in" {
  // A name that is an entry is that entry, whatever else is there: on a
  // file system that tells `report.pdf` from `REPORT.pdf`, a change of one
  // is not a change of the other.
  inspect(
    resolved(["report.pdf", "REPORT.pdf", "main.typ"], ["report.pdf"]),
    content="report.pdf <- /dir/report.pdf",
  )
  // A name that is not an entry is found under another spelling, which is
  // how a file system that ignores case or normalizes names opened it.
  inspect(
    resolved(["Chapter.typ", "main.typ"], ["chapter.typ", "main.typ"]),
    content="main.typ <- /dir/main.typ; Chapter.typ <- /dir/chapter.typ",
  )
  inspect(
    resolved(["e\u{301}.typ"], ["\u{e9}.typ"]) ==
    "e\u{301}.typ <- /dir/\u{e9}.typ",
    content="true",
  )
  // Two spellings of one entry.
  inspect(
    resolved(["Chapter.typ"], ["chapter.typ", "CHAPTER.typ"]),
    content="Chapter.typ <- /dir/chapter.typ /dir/CHAPTER.typ",
  )
  // No entry, or no single one: the name as it is.
  inspect(resolved(["a.typ"], ["b.typ"]), content="b.typ <- /dir/b.typ")
  inspect(
    resolved(["Report.pdf", "REPORT.pdf"], ["report.pdf"]),
    content="report.pdf <- /dir/report.pdf",
  )
}

///|
test "sites" {
  @debug.debug_inspect(
    sites("no/such/file.typ"),
    content=(
      #|[("no/such", "file.typ")]
    ),
  )
  @debug.debug_inspect(sites("/"), content="[]")
}

///|
async test "the events of changes to watched paths" {
  @async.with_task_group(group => {
    let dir = scratch("events")
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    write(a, "a")
    write(b, "b")
    write("\{dir}/other.typ", "other")
    let (watcher, rx) = RecommendedWatcher::new(group)
    watcher.watch(a)
    watcher.watch(b)
    // Nothing is watched before the commit.
    write(a, "early")
    inspect(rx.recv_timeout(Some(300)) is None, content="true")
    watcher.commit()

    // A file that is not watched.
    write("\{dir}/other.typ", "changed")
    @fs.remove("\{dir}/other.typ")
    inspect(rx.recv_timeout(Some(400)) is None, content="true")

    // Writing in place.
    write(a, "changed")
    inspect(drain(rx, dir), content="modify a.typ")

    // Replacing by a rename: the name gets another file.
    write("\{dir}/a.typ.tmp", "replaced")
    @fs.rename("\{dir}/a.typ.tmp", a, replace=true)
    inspect(drain(rx, dir), content="remove a.typ, create a.typ")
    // The new file is followed.
    write(a, "changed again")
    inspect(drain(rx, dir), content="modify a.typ")

    // Removing and creating.
    @fs.remove(b)
    inspect(drain(rx, dir), content="remove b.typ")
    write(b, "back")
    inspect(drain(rx, dir), content="create b.typ")

    // Renaming one watched path to another.
    @fs.remove(b)
    inspect(drain(rx, dir), content="remove b.typ")
    @fs.rename(a, b)
    inspect(drain(rx, dir), content="rename from a.typ, rename to b.typ")
  })
}

///|
async test "an unwatched path is reported until the next commit" {
  @async.with_task_group(group => {
    let dir = scratch("retired")
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    write(a, "a")
    write(b, "b")
    let (watcher, rx) = RecommendedWatcher::new(group)
    watcher.watch(a)
    watcher.watch(b)
    watcher.commit()
    watcher.unwatch(a)
    write(a, "changed")
    inspect(drain(rx, dir), content="modify a.typ")
    watcher.commit()
    write(a, "changed again")
    inspect(rx.recv_timeout(Some(400)) is None, content="true")
    // The watcher still serves the other path.
    write(b, "changed")
    inspect(drain(rx, dir), content="modify b.typ")
  })
}

///|
async test "a name that is spelled differently in the directory" {
  @async.with_task_group(group => {
    let dir = scratch("spelling")
    write("\{dir}/Chapter.typ", "a")
    let (watcher, rx) = RecommendedWatcher::new(group)
    // As a case-insensitive file system lets a document spell it.
    let path = "\{dir}/chapter.typ"
    watcher.watch(path)
    watcher.commit()
    write("\{dir}/Chapter.typ", "changed")
    inspect(drain(rx, dir), content="modify chapter.typ")
  })
}

///|
async test "a directory that cannot be watched" {
  @async.with_task_group(group => {
    let dir = scratch("gone")
    let (watcher, _) = RecommendedWatcher::new(group)
    watcher.watch("\{dir}/missing/a.typ")
    // Like notify's error for a path it cannot watch: the `io::Error` and
    // the path.
    try watcher.commit() catch {
      err =>
        inspect(
          err,
          content=(
            #|No such file or directory (os error 2) about ["_build/kit_watcher_test/gone/missing/a.typ"]
          ),
        )
    } noraise {
      _ => fail("expected an error")
    }
  })
}

///|
async test "a path that is watched later in a directory" {
  @async.with_task_group(group => {
    let dir = scratch("later")
    let a = "\{dir}/a.typ"
    let b = "\{dir}/b.typ"
    write(a, "a")
    write(b, "b")
    let (watcher, rx) = RecommendedWatcher::new(group)
    watcher.watch(a)
    watcher.commit()
    guard watcher.dirs.get(dir) is Some(first) else { fail("no watcher") }
    // What happens to the first path before the directory gets its new
    // watcher is reported by the old one.
    write(a, "changed")
    watcher.watch(b)
    watcher.commit()
    guard watcher.dirs.get(dir) is Some(second) else { fail("no watcher") }
    inspect(physical_equal(first, second), content="false")
    inspect(watcher.dirs.length(), content="1")
    inspect(drain(rx, dir), content="modify a.typ")
    // Both paths are reported, also when the old watcher is gone.
    write(b, "changed")
    inspect(drain(rx, dir), content="modify b.typ")
    @async.sleep(LINGER + 200)
    write(a, "changed again")
    inspect(drain(rx, dir), content="modify a.typ")
    write(b, "changed again")
    inspect(drain(rx, dir), content="modify b.typ")
  })
}

///|
async test "a link is watched where it is and where its file is" {
  @async.with_task_group(group => {
    let dir = scratch("link")
    @fs.mkdir("\{dir}/data")
    let file = "\{dir}/data/table.csv"
    let link = "\{dir}/table.csv"
    write(file, "1")
    @fs.symlink(target="data/table.csv", link)
    guard @platform.lstat_kind(link) is Symlink else {
      // This target cannot tell a link.
      return
    }
    inspect(sites(link).length(), content="2")
    let (watcher, rx) = RecommendedWatcher::new(group)
    watcher.watch(link)
    watcher.commit()
    inspect(watcher.dirs.length(), content="2")
    // The file is written in place.
    write(file, "2")
    inspect(drain(rx, dir), content="modify table.csv")
    // The file is replaced: neither the link nor its directory changes.
    write("\{file}.tmp", "3")
    @fs.rename("\{file}.tmp", file, replace=true)
    inspect(drain(rx, dir), content="remove table.csv, create table.csv")
    // The link is made to point elsewhere. kqueue reports it; with inotify
    // nothing is reported (the header of `notify.mbt`), as with notify's
    // inotify backend, which watches the file the link pointed to.
    write("\{dir}/data/other.csv", "4")
    @fs.remove(link)
    @fs.symlink(target="data/other.csv", link)
    let repointed = drain(rx, dir)
    inspect(
      repointed == "remove table.csv, create table.csv" || repointed == "",
      content="true",
    )
    // Watched anew, the link's new file is followed.
    watcher.unwatch(link)
    watcher.watch(link)
    watcher.commit()
    write("\{dir}/data/other.csv", "5")
    inspect(drain(rx, dir), content="modify table.csv")
    // (Once the watcher of the old file is gone.)
    @async.sleep(LINGER + 200)
    write(file, "6")
    inspect(rx.recv_timeout(Some(400)) is None, content="true")
  })
}
