///|
test "portable member names retain relative components" {
  assert_eq(components("a//./b/"), ["a", "b"])
  assert_eq(components("./"), [])
}

///|
test "portable member names reject parent roots and platform aliases" {
  for
    name in [
      "", "..", "d/../p", "/abs", "C:/p", "d\\p", "aux.txt", "d/CoM¹", "a.", "b ",
      "a:b", "x\u0000y",
    ] {
    try components(name) catch {
      ArchiveError(_) => ()
    } noraise {
      _ => fail("accepted member " + name)
    }
  }
}

///|
async test "a bad selected member leaves the extraction directory absent" {
  let parent = @fs.tmpdir(prefix="archivefs-selection-")
  defer @fs.remove(parent, recursive=true)
  let output = parent + "/out"
  let first : Member = { name: "first", content: Regular(b"a"), }
  let invalid : Array[Member] = [
    { name: "FIRST", content: Regular(b"b"), },
    { name: "first/child", content: Regular(b"b"), },
    { name: "missing", content: Special, },
    { name: "/absolute", content: Directory, },
  ]
  for entry in invalid {
    try extract([first, entry], output) catch {
      ArchiveError(_) => ()
      other => raise other
    } noraise {
      _ => fail("invalid member was extracted")
    }
    assert_false(@fs.exists(output))
  }
}
