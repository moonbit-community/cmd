// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

///|
test "absolutize keeps backslashes and parent components on Unix" {
  if @platform.os() == Windows {
    return
  }
  inspect(@platform.absolutize("/tmp/a\\b"), content="/tmp/a\\b")
  inspect(
    @platform.absolutize("/tmp/./link/../x//y"),
    content="/tmp/link/../x/y",
  )
  inspect(@platform.absolutize("/"), content="/")
}

///|
test "double backslashes are not UNC prefixes on Unix" {
  if @platform.os() == Windows {
    return
  }
  inspect(@platform.is_absolute("\\\\server\\share"), content="false")
  inspect(@platform.join("/base", "\\\\x"), content="/base/\\\\x")
}

///|
test "path helpers" {
  @debug.debug_inspect(
    @platform.parent("/a/b/c.typ"),
    content=(
      #|Some("/a/b")
    ),
  )
  @debug.debug_inspect(
    @platform.parent("/a"),
    content=(
      #|Some("/")
    ),
  )
  @debug.debug_inspect(@platform.parent("/"), content="None")
  @debug.debug_inspect(
    @platform.parent("c.typ"),
    content=(
      #|Some("")
    ),
  )
  @debug.debug_inspect(
    @platform.file_name("/a/b/c.typ"),
    content=(
      #|Some("c.typ")
    ),
  )
  @debug.debug_inspect(@platform.file_name("/a/.."), content="None")
  inspect(@platform.join("/a", "b"), content="/a/b")
  inspect(@platform.join("/a/", "b"), content="/a/b")
  inspect(@platform.join("/a", "/b"), content="/b")
}

///|
test "file errors" {
  let err = try @platform.read_file("/nonexistent/typst-mbt-test") catch {
    e => {
      assert_eq(e.kind(), @platform.NotFound)
      "\{@debug.to_string(e.kind())}: \{e}"
    }
  } noraise {
    _ => fail("missing input unexpectedly readable")
  }
  if @platform.os() != Windows {
    inspect(err, content="NotFound: No such file or directory (os error 2)")
  }
  let err = try @platform.read_file("a\u{0}b") catch {
    e => "\{@debug.to_string(e.kind())}: \{e}"
  } noraise {
    _ => "ok"
  }
  inspect(
    err,
    content="InvalidInput: file name contained an unexpected NUL byte",
  )
}

///|
test "os errors" {
  inspect(
    @platform.os_error(2),
    content="No such file or directory (os error 2)",
  )
  inspect(@platform.os_error(24), content="Too many open files (os error 24)")
  @debug.debug_inspect(@platform.os_error(2).kind(), content="NotFound")
}

///|
test "monotonic clock" {
  let start = @platform.monotonic_nanos()
  let mut sum = 0
  for i in 0..<100000 {
    sum += i
  }
  inspect(sum > 0 && @platform.monotonic_nanos() >= start, content="true")
}

///|
test "is_same_file" {
  // The directory of the tests is the module's or the package's.
  let dir = "internal/kit/platform"
  let file = @platform.join(dir, "moon.pkg")
  inspect(@platform.is_same_file(file, file), content="true")
  inspect(
    @platform.is_same_file(file, @platform.join(dir, "./moon.pkg")),
    content="true",
  )
  inspect(
    @platform.is_same_file(file, @platform.join(dir, "platform.mbt")),
    content="false",
  )
  let missing = try
    @platform.is_same_file(file, @platform.join(dir, "no-such-file"))
  catch {
    err => err.kind() == NotFound
  } noraise {
    _ => false
  }
  inspect(missing, content="true")
}

///|
test "read_dir: the entries without `.` and `..`" {
  let dir = "_build/kit_platform_test/listing"
  @platform.create_dir_all(@platform.join(dir, "sub"))
  @platform.write_file(@platform.join(dir, "a.txt"), b"a")
  @platform.write_file(@platform.join(dir, ".hidden"), b"")
  @platform.write_file(@platform.join(dir, "sub/inside"), b"")
  let names = @platform.read_dir(dir)
  names.sort()
  inspect(names.join(", "), content="sub, a.txt, .hidden")
  let entries = @platform.read_dir_entries(dir).map(entry => entry.name)
  entries.sort()
  inspect(entries.join(", "), content="sub, a.txt, .hidden")
  inspect(
    @platform.read_dir(@platform.join(dir, "sub")).join(", "),
    content="inside",
  )
}

///|
/// Writes a file for a test below the build directory and returns its path.
fn scratch_file(name : String, data : Bytes) -> String raise {
  let dir = "_build/kit_platform_test"
  @platform.create_dir_all(dir)
  let path = @platform.join(dir, name)
  @platform.write_file(path, data)
  path
}

///|
test "ranged file: pieces, the end of the file, closing" {
  let data = Bytes::makei(1000, i => (i % 251).to_byte())
  let path = scratch_file("ranged.bin", data)
  let file = @platform.RangedFile::open(path)
  inspect(file.size(), content="1000")
  inspect(file.read(0L, 1000) == data, content="true")
  inspect(file.read(250L, 4) == b"\xfa\x00\x01\x02", content="true")
  inspect(file.read(996L, 4) == b"\xf3\xf4\xf5\xf6", content="true")
  inspect(file.read(10L, 0).length(), content="0")
  // A piece that ends beyond the file is cut, one that starts there is
  // empty.
  inspect(file.read(990L, 100) == data[990:].to_owned(), content="true")
  inspect(file.read(1000L, 5).length(), content="0")
  inspect(file.read(5000000000L, 5).length(), content="0")
  let negative = try file.read(-1L, 5) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
  inspect(negative, content="Invalid argument (os error 22)")
  // A closed file fails (the same way on every target), and closing twice
  // is fine.
  file.close()
  file.close()
  let closed = try file.read(0L, 10) catch {
    e => "\{@debug.to_string(e.kind())}: \{e}"
  } noraise {
    bytes => "\{bytes.length()} bytes"
  }
  inspect(closed, content="Other: Bad file descriptor (os error 9)")
  let closed = try file.read(-1L, 10) catch {
    e => e.to_string()
  } noraise {
    bytes => "\{bytes.length()} bytes"
  }
  inspect(closed, content="Bad file descriptor (os error 9)")
  let closed = try file.size() catch {
    e => "\{@debug.to_string(e.kind())}: \{e}"
  } noraise {
    size => "\{size} bytes"
  }
  inspect(closed, content="Other: Bad file descriptor (os error 9)")
}

///|
test "ranged file: errors of open" {
  let missing = try
    @platform.RangedFile::open("/nonexistent/typst-mbt-test")
  catch {
    e => {
      assert_eq(e.kind(), @platform.NotFound)
      "\{@debug.to_string(e.kind())}: \{e}"
    }
  } noraise {
    _ => fail("missing input unexpectedly readable")
  }
  if @platform.os() != Windows {
    inspect(missing, content="NotFound: No such file or directory (os error 2)")
  }
  // The directory of the tests is the module's or the package's.
  let dir = "internal/kit/platform"
  let directory = try @platform.RangedFile::open(dir) catch {
    e => "\{@debug.to_string(e.kind())}: \{e}"
  } noraise {
    _ => "ok"
  }
  inspect(directory, content="IsADirectory: Is a directory (os error 21)")
  let nul = try @platform.RangedFile::open("a\u{0}b") catch {
    e => @debug.to_string(e.kind())
  } noraise {
    _ => "ok"
  }
  inspect(nul, content="InvalidInput")
}
