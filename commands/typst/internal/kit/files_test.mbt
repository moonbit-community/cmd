///|
/// A loader serving fixed files (like upstream's `TestLoader`).
struct TestLoader {
  generation : Ref[Int32]
  loads : Ref[Int32]
}

///|
impl @kit.FileLoader for TestLoader with fn load(self, id) {
  self.loads.val += 1
  match id.vpath().get_without_slash() {
    "a.typ" => @utf8.encode("Hello from A")
    "b.typ" => b"\xef\xbb\xbfHello from B"
    "c.bin" => b"a\xFF\xFF\xFFb"
    "d.typ" => @utf8.encode(self.generation.val.to_string())
    "e.bin" if self.generation.val > 3 => @utf8.encode("A secret")
    "f.typ" =>
      @utf8.encode(
        "= Title\n\n#let f(x) = { x + \{self.generation.val} }\n\nThe end.\n",
      )
    path => raise @library.FileError::NotFound(path)
  }
}

///|
fn id(path : String) -> @syntax.FileId {
  @syntax.RootedPath::new(Project, @syntax.VirtualPath::new(path)).intern() catch {
    _ => panic()
  }
}

///|
fn new_store() -> @kit.FileStore[TestLoader] {
  @kit.FileStore::new({ generation: { val: 1, }, loads: { val: 0, }, })
}

///|
test "file store: file then source" {
  let store = new_store()
  inspect(@utf8.decode(store.file(id("a.typ"))), content="Hello from A")
  inspect(store.source(id("a.typ")).text(), content="Hello from A")
  inspect(store.loader().loads.val, content="1")
}

///|
test "file store: BOM is kept in the file but stripped in the source" {
  let store = new_store()
  inspect(store.file(id("b.typ")).length(), content="15")
  inspect(store.source(id("b.typ")).text(), content="Hello from B")
}

///|
test "file store: invalid UTF-8 and missing files" {
  let store = new_store()
  inspect(store.file(id("c.bin")).length(), content="5")
  let err = try store.source(id("c.bin")) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(err, content="file is not valid UTF-8")
  let err = try store.file(id("e.bin")) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(err, content="file not found (searched at e.bin)")
  // Errors are cached.
  let loads = store.loader().loads.val
  ignore(store.file(id("e.bin"))) catch {
    _ => ()
  }
  inspect(store.loader().loads.val == loads, content="true")
}

///|
test "file store: reset reloads and tracks dependencies" {
  let store = new_store()
  let deps = () => {
    let names = store.dependencies().map(i => i.vpath().get_without_slash())
    names.sort_by((a, b) => @library.compare_str(a, b))
    names
  }
  let a = store.source(id("a.typ"))
  inspect(a.text(), content="Hello from A")
  let d = store.source(id("d.typ"))
  inspect(d.text(), content="1")
  ignore(store.file(id("e.bin"))) catch {
    _ => ()
  }
  @debug.debug_inspect(deps(), content="[\"a.typ\", \"d.typ\", \"e.bin\"]")
  store.loader().generation.val = 5
  store.reset()
  // The stale source is edited: the slot has the edited source, and the
  // one that was handed out before the reset is what it was (upstream: a
  // clone of the slot's source, which `Source::replace` does not change).
  let d2 = store.source(id("d.typ"))
  inspect(physical_equal(d, d2), content="false")
  inspect(d2.text(), content="5")
  inspect(d.text(), content="1")
  inspect(d.root().full_text(), content="1")
  inspect(physical_equal(store.source(id("d.typ")), d2), content="true")
  inspect(@utf8.decode(store.file(id("e.bin"))), content="A secret")
  @debug.debug_inspect(deps(), content="[\"d.typ\", \"e.bin\"]")
  // A file whose text is the same after a reset has the same source.
  inspect(physical_equal(store.source(id("a.typ")), a), content="true")
  @debug.debug_inspect(deps(), content="[\"a.typ\", \"d.typ\", \"e.bin\"]")
}

///|
test "utc date time from timestamps" {
  @debug.debug_inspect(
    @kit.UtcDateTime::from_timestamp(0L),
    content=(
      #|Some({ year: 1970, month: 1, day: 1, hour: 0, minute: 0, second: 0 })
    ),
  )
  @debug.debug_inspect(
    @kit.UtcDateTime::from_timestamp(1700000000L),
    content=(
      #|Some({ year: 2023, month: 11, day: 14, hour: 22, minute: 13, second: 20 })
    ),
  )
  @debug.debug_inspect(
    @kit.UtcDateTime::from_timestamp(-1L),
    content=(
      #|Some({ year: 1969, month: 12, day: 31, hour: 23, minute: 59, second: 59 })
    ),
  )
  inspect(
    @kit.UtcDateTime::from_timestamp(99999999999999999L) is None,
    content="true",
  )
}

///|
/// A duration of the given number of hours.
fn hours(n : Int32) -> @library.Duration {
  let a = @library.Datetime::from_ymd_hms(2000, 1, 1, 0, 0, 0).unwrap()
  let b = @library.Datetime::from_ymd_hms(2000, 1, 1 + n / 24, n % 24, 0, 0).unwrap()
  b.sub_datetime(a) catch {
    _ => panic()
  }
}

///|
test "fixed time today" {
  let time = @kit.Time::fixed_timestamp(1700000000L)
  inspect(
    time.today(None).map(d => d.repr()).unwrap_or(""),
    content="datetime(year: 2023, month: 11, day: 14)",
  )
  inspect(
    time.today(Some(hours(2))).map(d => d.repr()).unwrap_or(""),
    content="datetime(year: 2023, month: 11, day: 15)",
  )
  inspect(time.today(Some(hours(24))) is None, content="true")
  let err = try @kit.Time::fixed_timestamp(99999999999999999L) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(err, content="timestamp is out of range")
}

///|
test "rust trim" {
  inspect(@kit.rust_trim(" \t key \u{3000}"), content="key")
  inspect(@kit.rust_trim(""), content="")
}

///|
test "file store: a source after a reset shares the nodes outside of the edit" {
  let store = new_store()
  let before = store.source(id("f.typ"))
  let heading = before.root().children()[0]
  inspect(heading.full_text(), content="= Title")
  let numbers = (source : @syntax.Source) => {
    source.root().children().map(node => node.span().number())
  }
  store.loader().generation.val = 22
  store.reset()
  let after = store.source(id("f.typ"))
  inspect(
    after.text(),
    content="= Title\n\n#let f(x) = { x + 22 }\n\nThe end.\n",
  )
  // The tree was edited, not parsed anew: the nodes around the edit are the
  // same objects, so the spans that an earlier compilation holds still
  // name them.
  inspect(physical_equal(after.root().children()[0], heading), content="true")
  assert_eq(numbers(after), numbers(before))
  // And the source of before the reset is what it was.
  inspect(
    before.text(),
    content="= Title\n\n#let f(x) = { x + 1 }\n\nThe end.\n",
  )
  inspect(before.root().full_text() == before.text(), content="true")
  inspect(physical_equal(before.root().children()[0], heading), content="true")
}
