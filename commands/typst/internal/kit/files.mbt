// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// File loading and management (upstream `typst_kit::files`).

///|
/// Provides data for files, backing a [`FileStore`].
///
/// If you want to load files in a different way, the first step would be to
/// create your own type that implements [`FileLoader`]. For an example, you
/// can take a look at how `typst-cli` implements it.
pub(open) trait FileLoader {
  /// Load the data for the given file ID.
  ///
  /// Generally, here you'll want to match on the
  /// [`root()`](typst_syntax::RootedPath::root) of the `id` to check whether
  /// the file should be loaded from the project or a package. Then, you'll
  /// load the data at the path
  /// [`id.vpath()`](typst_syntax::RootedPath::vpath) in the project /
  /// package.
  fn load(Self, @syntax.FileId) -> Bytes raise @library.FileError
}

///|
/// Holds loaded files and sources.
///
/// This type is backed by a file loader of your choosing. Internally, it
/// handles caching of loaded files and creation of Typst [sources](Source).
pub struct FileStore[L] {
  priv loader : L
  priv slots : Map[@syntax.FileId, FileSlot]
}

///|
/// Creates a new file store that loads file data via the provided `loader`.
pub fn[L] FileStore::new(loader : L) -> FileStore[L] {
  { loader, slots: {}, }
}

///|
/// Returns a reference to the underlying loader.
pub fn[L] FileStore::loader(self : FileStore[L]) -> L {
  self.loader
}

///|
/// Retrieves the given file id as a Typst source.
///
/// Can directly be used to implement `World::source`.
pub fn[L : FileLoader] FileStore::source(
  self : FileStore[L],
  id : @syntax.FileId,
) -> @syntax.Source raise @library.FileError {
  let slot = self.slots.get(id).unwrap_or(Empty(None))
  let (next, result) = slot.source(self.loader, id)
  self.slots[id] = next
  match result {
    Ok(source) => source
    Err(err) => raise err
  }
}

///|
/// Retrieves the given file id as a raw file.
///
/// Can directly be used to implement `World::file`.
pub fn[L : FileLoader] FileStore::file(
  self : FileStore[L],
  id : @syntax.FileId,
) -> Bytes raise @library.FileError {
  let slot = self.slots.get(id).unwrap_or(Empty(None))
  let (next, result) = slot.file(self.loader, id)
  self.slots[id] = next
  match result {
    Ok(bytes) => bytes
    Err(err) => raise err
  }
}

///|
/// Returns all files that were referenced since the last
/// [`reset()`](Self::reset).
///
/// The dependencies are returned in arbitrary order! If you want to get a
/// consistent result, you should sort them by a suitable criterion after
/// the fact.
pub fn[L] FileStore::dependencies(self : FileStore[L]) -> Array[@syntax.FileId] {
  let out = []
  for id, slot in self.slots {
    if slot.accessed() {
      out.push(id)
    }
  }
  out
}

///|
/// Resets the store.
///
/// This marks all loaded file as stale. On subsequent accesses, they will
/// be loaded once more through the underlying loader. Moreover, calls to
/// [`dependencies()`](Self::dependencies) will not yield files accessed
/// before the call to `reset()`.
///
/// Unlike when creating an entirely new store, source files will be edited
/// in place with updated data, leading to improved incremental compilation
/// performance.
pub fn[L] FileStore::reset(self : FileStore[L]) -> Unit {
  let ids = self.slots.keys().to_array()
  for id in ids {
    self.slots[id] = self.slots[id].reset()
  }
}

///|
/// Holds the state for a file.
priv enum FileSlot {
  /// Nothing is loaded that, but we may have a stale source from before a
  /// reset (i.e. from an earlier compilation) that we can reuse and edit in
  /// place.
  ///
  /// Transitions to
  /// - loaded when a file is requested
  /// - to parsed if a source is requested and the data could be loaded
  ///   (otherwise to loaded).
  Empty(@syntax.Source?)
  /// The slot has been requested as a `file()` but not as a `source()` (at
  /// least since the last reset). We can still have a stale, reusable
  /// source.
  ///
  /// Transitions to
  /// - parsed when a source is requested
  Loaded(Result[Bytes, @library.FileError], @syntax.Source?)
  /// The slot has been requested as a `source()` and potentially as a
  /// `file()`.
  ///
  /// The bytes are retained as loaded (with a potential UTF-8 BOM, which is
  /// stripped for the source).
  Parsed(Result[@syntax.Source, @library.FileError], Bytes)
}

///|
/// Whether the slot has been accessed in any way since the last reset.
fn FileSlot::accessed(self : FileSlot) -> Bool {
  !(self is Empty(_))
}

///|
/// Resets the slot to its empty state.
fn FileSlot::reset(self : FileSlot) -> FileSlot {
  match self {
    Parsed(Ok(source), _) => Empty(Some(source))
    _ => Empty(None)
  }
}

///|
/// Loads the bytes of a file, catching the error.
// The result is cached as data in FileSlot::Loaded, including failures
// (upstream typst-kit/src/files.rs:180-181).
#warnings("-result_error_return")
fn[L : FileLoader] load_result(
  loader : L,
  id : @syntax.FileId,
) -> Result[Bytes, @library.FileError] {
  try loader.load(id) catch {
    err => Err(err)
  } noraise {
    bytes => Ok(bytes)
  }
}

///|
/// Retrieves the slot's bytes. Returns the new state of the slot.
fn[L : FileLoader] FileSlot::file(
  self : FileSlot,
  loader : L,
  id : @syntax.FileId,
) -> (FileSlot, Result[Bytes, @library.FileError]) {
  match self {
    Empty(stale) => {
      let result = load_result(loader, id)
      (Loaded(result, stale), result)
    }
    Loaded(result, _) => (self, result)
    Parsed(_, bytes) => (self, Ok(bytes))
  }
}

///|
/// Retrieves the source for this slot. Returns the new state of the slot.
///
/// Upstream returns a clone of the slot's source (files.rs:206, :230), which
/// keeps its text and tree when the slot's source is edited after a reset.
/// Here a `Source` never changes (`syntax/source.mbt`), so the slot's source
/// itself is returned, and after a reset the slot holds the edited one.
fn[L : FileLoader] FileSlot::source(
  self : FileSlot,
  loader : L,
  id : @syntax.FileId,
) -> (FileSlot, Result[@syntax.Source, @library.FileError]) {
  // When we already have a source or error, this returns. Otherwise, it
  // loads or extracts the bytes and a potential stale source file.
  let (bytes, stale) = match self {
    Empty(stale) =>
      match load_result(loader, id) {
        Ok(bytes) => (bytes, stale)
        Err(err) => return (Loaded(Err(err), stale), Err(err))
      }
    Loaded(Ok(bytes), stale) => (bytes, stale)
    Loaded(Err(err), _) => return (self, Err(err))
    Parsed(source, _) => return (self, source)
  }

  // Strip a UTF-8 BOM.
  let without_bom = if bytes.length() >= 3 &&
    bytes[0] == b'\xef' &&
    bytes[1] == b'\xbb' &&
    bytes[2] == b'\xbf' {
    bytes[3:]
  } else {
    bytes[:]
  }

  // Create a source file, with various attempts to reuse things.
  let result : Result[@syntax.Source, @library.FileError] = try
    @utf8.decode(without_bom)
  catch {
    _ => Err(@library.FileError::InvalidUtf8)
  } noraise {
    text =>
      match stale {
        // If we have a stale source file, reuse it. (Upstream:
        // `source.replace(new)` on the slot's own source, files.rs:216.
        // Here `replace` returns the edited source and the stale one, which
        // an earlier compilation may still hold, stays as it was.)
        Some(source) => Ok(source.replace(text).0)
        None => Ok(@syntax.Source::new(id, text))
      }
  }
  (Parsed(result, bytes), result)
}

///|
/// A [root](typst_syntax::VirtualRoot) that is backed by a file system
/// directory.
///
/// A Typst project forms a root. Similarly, each package has its own root.
/// Through this mechanism, projects and packages are isolated from each
/// other.
#derive(Eq, Hash, Debug)
pub(all) struct FsRoot(String)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FsRoot with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FsRoot with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FsRoot with @debug.Debug::{to_repr}

///|
/// Creates a new instance with the given root path.
pub fn FsRoot::new(root : String) -> FsRoot {
  FsRoot(root)
}

///|
/// The path at which the root resides in the file system.
pub fn FsRoot::path(self : FsRoot) -> String {
  self.0
}

///|
/// Resolves the real file system path for the given virtual path in this
/// root.
pub fn FsRoot::resolve(
  self : FsRoot,
  path : @syntax.VirtualPath,
) -> String raise @library.FileError {
  path.realize(self.0) catch {
    err => raise @library.FileError::Realize(err)
  }
}

///|
/// Loads file data from the given virtual path in this root.
pub fn FsRoot::load(
  self : FsRoot,
  path : @syntax.VirtualPath,
) -> Bytes raise @library.FileError {
  // Join the path to the root. If it tries to escape, deny access. Note:
  // It can still escape via symlinks.
  let path = self.resolve(path)
  let kind = @platform.stat_kind(path) catch {
    err => raise file_error_from_io(err, path)
  }
  if kind == Dir {
    raise @library.FileError::IsDirectory
  } else {
    @platform.read_file(path) catch {
      err => raise file_error_from_io(err, path)
    }
  }
}

///|
/// Create a file error from an I/O error (upstream `FileError::from_io`).
pub fn file_error_from_io(
  err : @platform.IoError,
  path : String,
) -> @library.FileError {
  match err.kind() {
    NotFound => @library.FileError::NotFound(path)
    PermissionDenied => @library.FileError::AccessDenied
    _ => @library.FileError::Other(Some(err.to_string()))
  }
}

///|
/// An error message (upstream `StrResult`'s error).
pub(all) suberror StrError {
  StrError(String)
}

///|
pub impl Show for StrError with fn output(self, logger) {
  let StrError(message) = self
  logger.write_string(message)
}

///|
pub extend StrError with Show::{to_string, output}

///|
/// Rust's `str::trim` (Unicode `White_Space`).
pub fn rust_trim(s : String) -> String {
  let chars = s.to_array()
  let mut start = 0
  let mut end = chars.length()
  while start < end && @unicode.is_whitespace(chars[start]) {
    start += 1
  }
  while end > start && @unicode.is_whitespace(chars[end - 1]) {
    end -= 1
  }
  String::from_array(chars[start:end])
}
