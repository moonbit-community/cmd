// File system helpers for the (native only) tests that need a scratch
// directory, mirroring the `TempDir` helper of the Rust test suite.

///|
/// A scratch directory under `<cwd>/_build/tmp-ignore-tests/<name>`.
priv struct TempDir(String)

///|
async fn TempDir::new(name : String) -> TempDir {
  let cwd = @sys.current_dir().unwrap()
  let path = cwd + "/_build/tmp-ignore-tests/" + name
  let exists = try {
    @sys.symlink_metadata(path) |> ignore
    true
  } catch {
    _ => false
  }
  if exists {
    @sys.remove_dir_all(path) catch {
      e => fail("failed to remove \{path}: \{e}")
    }
  }
  @sys.create_dir_all(path) catch {
    e => fail("failed to create \{path}: \{e}")
  }
  TempDir(path)
}

///|
fn TempDir::path(self : TempDir) -> String {
  self.0
}

///|
fn TempDir::join(self : TempDir, p : String) -> String {
  path_join(self.0, p)
}

///|
async fn TempDir::close(self : TempDir) -> Unit {
  @sys.remove_dir_all(self.0) catch {
    e => fail("failed to remove \{self.0}: \{e}")
  }
}

///|
async fn wfile(path : String, contents : String) -> Unit {
  @sys.write_file(path, @utf8.encode(contents)) catch {
    e => fail("failed to write \{path}: \{e}")
  }
}

///|
async fn wfile_size(path : String, size : Int32) -> Unit {
  @sys.write_file(path, Bytes::make(size, b'\x00')) catch {
    e => fail("failed to write \{path}: \{e}")
  }
}

///|
async fn mkdirp(path : String) -> Unit {
  @sys.create_dir_all(path) catch {
    e => fail("failed to create \{path}: \{e}")
  }
}

///|
async fn symlink(src : String, dst : String) -> Unit {
  @sys.symlink(src, dst) catch {
    e => fail("failed to symlink \{dst} -> \{src}: \{e}")
  }
}
