///|
async test "recursive copy rejects a destination inside its source" {
  let root = @fs.tmpdir(prefix="mooncmd-fsops")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  @fs.mkdir(@fsops.join(source, "child"), recursive=true)
  @fs.write_file(@fsops.join(source, "file"), b"content")
  try
    copy_path_with_links(
      source,
      @fsops.join(source, "child/copy"),
      true,
      true,
      NeverFollowLinks,
    )
  catch {
    _ => assert_false(@fs.exists(@fsops.join(source, "child/copy")))
  } noraise {
    _ => fail("expected nested-destination error")
  }
}

///|
async test "copy rejects unsafe overwrite without changing either file" {
  let root = @fs.tmpdir(prefix="mooncmd-copy-overwrite")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  @fs.write_file(source, b"source bytes")
  @fs.write_file(destination, b"destination bytes")
  try
    copy_path_with_links(
      source,
      destination,
      false,
      true,
      FollowCommandLineLinks,
      preserve_permissions=false,
    )
  catch {
    _ => {
      assert_eq(@fs.read_file(source).binary(), b"source bytes")
      assert_eq(@fs.read_file(destination).binary(), b"destination bytes")
    }
  } noraise {
    _ => fail("unsafe overwrite succeeded")
  }
  try
    copy_path_with_links(
      source,
      source,
      false,
      true,
      FollowCommandLineLinks,
      preserve_permissions=false,
    )
  catch {
    _ => assert_eq(@fs.read_file(source).binary(), b"source bytes")
  } noraise {
    _ => fail("same-file overwrite succeeded")
  }
}

///|
async test "copy supports explicit no-preserve mode only for new files" {
  let root = @fs.tmpdir(prefix="mooncmd-copy-new")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  let buffer = FixedArray::make(65536 * 2 + 7, b'\x00')
  for index in 0..<buffer.length() {
    buffer[index] = (index % 256).to_byte()
  }
  let bytes = buffer.unsafe_reinterpret_as_bytes()
  @fs.write_file(source, bytes)
  try
    copy_path_with_links(source, destination, false, true, NeverFollowLinks)
  catch {
    _ => assert_false(@fs.exists(destination))
  } noraise {
    _ => fail("default copy cannot preserve source mode")
  }
  ignore(
    copy_path_with_links(
      source,
      destination,
      false,
      true,
      FollowCommandLineLinks,
      preserve_permissions=false,
    ),
  )
  assert_eq(@fs.read_file(source).binary(), bytes)
  assert_eq(@fs.read_file(destination).binary(), bytes)
}

///|
async test "copy preflight rejects followed symbolic-link cycles before output" {
  if !@platform.symbolic_link_creation_supported() {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-fsops-cycle")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  let source = @fsops.join(root, "source")
  let destination = @fsops.join(root, "destination")
  @fs.mkdir(source)
  @fs.write_file(@fsops.join(source, "file"), b"content")
  @fs.symlink(@fsops.join(source, "loop"), target=source)
  try preflight_copy_path(source, destination, true, FollowAllLinks) catch {
    _ => assert_false(@fs.exists(destination))
  } noraise {
    _ => fail("expected symbolic-link cycle error")
  }
}
