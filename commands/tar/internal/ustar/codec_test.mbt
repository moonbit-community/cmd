///|
test "ustar keeps prefix names, binary payloads and empty directories" {
  let name = "folder/".repeat(25) + "data"
  let archive = @ustar.write([
    { name: "empty/", content: Directory, },
    { name, content: Regular(b"a\x00b\xff"), },
  ])
  let entries = @ustar.read(archive)
  assert_eq(entries.length(), 2)
  assert_true(entries[0].content is Directory)
  assert_eq(entries[1].name, name)
  guard entries[1].content is Regular(bytes) else {
    fail("expected regular entry")
  }
  assert_eq(bytes, b"a\x00b\xff")
}

///|
test "ustar rejects corrupt checksum and incomplete final records" {
  let archive = @ustar.write([{ name: "file", content: Regular(b"x"), }])
  for malformed in [archive[1:], archive[:1024], archive[:1536]] {
    try @ustar.read(malformed) catch {
      _ => ()
    } noraise {
      _ => fail("invalid tar accepted")
    }
  }
}
