// Synchronous file access through released moonbitlang/x/fs APIs.

///|
fn host_error_kind(code : Int32, host : Os) -> ErrorKind {
  if host != Windows {
    return kind_of_errno(code)
  }
  // Win32 error numbers differ from POSIX errno values.
  match code {
    2 | 3 => NotFound
    5 => PermissionDenied
    80 | 183 => AlreadyExists
    87 | 123 => InvalidInput
    _ => Other
  }
}

///|
/// Maps an `x/fs` error (moonrun reports Rust's `io::Error` display text,
/// e.g. `No such file or directory (os error 2)`) to an `IoError`.
fn fs_error(message : String, path : String) -> IoError {
  // moonrun appends the path to the message.
  let suffix = ": " + path
  let message = if message.has_suffix(suffix) {
    message[:message.length() - suffix.length()].to_owned()
  } else {
    message
  }
  let kind = match message.find("(os error ") {
    Some(i) => {
      let rest = message[i + 10:]
      let mut code = 0
      for c in rest {
        if c >= '0' && c <= '9' {
          code = code * 10 + (c.to_int() - '0'.to_int())
        } else {
          break
        }
      }
      host_error_kind(code, os())
    }
    None =>
      if message.contains("No such file") || message.contains("not found") {
        NotFound
      } else if message.contains("ermission denied") {
        PermissionDenied
      } else {
        Other
      }
  }
  IoError(kind, message)
}

///|
/// Like Rust's file system APIs, rejects paths with embedded NULs.
fn check_path(path : String) -> Unit raise IoError {
  if path.contains_char('\u{0}') {
    raise IoError(InvalidInput, "file name contained an unexpected NUL byte")
  }
}

///|
/// Reads a whole file.
pub fn read_file(path : String) -> Bytes raise IoError {
  match stat_kind(path) {
    Dir => raise IoError(IsADirectory, "Is a directory (os error 21)")
    _ => ()
  }
  @fs.read_file_to_bytes(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
}

///|
/// A file that is open for ranged reads: here the whole file, which is all
/// that the host can read.
pub struct RangedFile {
  /// `None` once the file is closed.
  priv mut data : Bytes?
}

///|
/// Opens a file for ranged reads.
pub fn RangedFile::open(path : String) -> RangedFile raise IoError {
  { data: Some(read_file(path)), }
}

///|
/// The file's bytes, or the error of the native backend for a closed file.
fn RangedFile::bytes(self : RangedFile) -> Bytes raise IoError {
  match self.data {
    Some(data) => data
    // EBADF
    None => raise os_error(9)
  }
}

///|
/// The size of the file in bytes.
pub fn RangedFile::size(self : RangedFile) -> Int64 raise IoError {
  self.bytes().length().to_int64()
}

///|
/// Reads up to `len` bytes at `offset`: fewer only if the file ends
/// before.
pub fn RangedFile::read(
  self : RangedFile,
  offset : Int64,
  len : Int32,
) -> Bytes raise IoError {
  let data = self.bytes()
  if offset < 0L || len < 0 {
    // EINVAL
    raise os_error(22)
  }
  let start = if offset > data.length().to_int64() {
    data.length()
  } else {
    offset.to_int()
  }
  let end = if len > data.length() - start {
    data.length()
  } else {
    start + len
  }
  data[start:end].to_owned()
}

///|
/// Closes the file. Reads fail afterwards.
pub fn RangedFile::close(self : RangedFile) -> Unit {
  self.data = None
}

///|
/// The kind of the entry at `path`, following symlinks (`fs::metadata`).
pub fn stat_kind(path : String) -> FileKind raise IoError {
  check_path(path)
  // `is_dir` reports the host's error (e.g. not found, not a directory).
  let is_dir = @fs.is_dir(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
  let is_file = @fs.is_file(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
  if is_dir {
    Dir
  } else if is_file {
    File
  } else {
    Other
  }
}

///|
/// The kind of the entry at `path`, not following symlinks. Symlinks
/// cannot be detected here, so this is `stat_kind`.
pub fn lstat_kind(path : String) -> FileKind raise IoError {
  stat_kind(path)
}

///|
/// Canonicalizes a path. The host offers no `realpath`, so symlinks cannot
/// be resolved here: the path is made absolute and `.` components are
/// removed, but `..` components are kept for the host to resolve (see
/// `absolutize`).
pub fn canonicalize(path : String) -> String raise IoError {
  stat_kind(path) |> ignore
  absolutize(path)
}

///|
/// Writes a whole file (`fs::write`).
pub fn write_file(path : String, data : Bytes) -> Unit raise IoError {
  check_path(path)
  @fs.write_bytes_to_file(path, data) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
}

///|
/// Creates a single directory (`fs::create_dir`).
pub fn create_dir(path : String) -> Unit raise IoError {
  check_path(path)
  if @fs.path_exists(path) {
    raise IoError(AlreadyExists, "File exists (os error 17)")
  }
  @fs.create_dir(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
}

///|
/// Lists the names of the entries of a directory (`fs::read_dir`).
pub fn read_dir(path : String) -> Array[String] raise IoError {
  match stat_kind(path) {
    Dir => ()
    _ => raise IoError(Other, "Not a directory (os error 20)")
  }
  let entries = @fs.read_dir(path) catch {
    @fs.IOError(message) => raise fs_error(message, path)
  }
  entries.to_owned()
}

///|
/// Lists the entries of a directory (`fs::read_dir`). The host tells no
/// kinds.
pub fn read_dir_entries(path : String) -> Array[DirEntry] raise IoError {
  read_dir(path).map(name => { name, kind: None, })
}

///|
/// Whether a path exists (`Path::exists`).
pub fn exists(path : String) -> Bool {
  !path.contains_char('\u{0}') && @fs.path_exists(path)
}

///|
/// Whether stderr is a terminal (unknown here, so `false`).
pub fn stderr_is_terminal() -> Bool {
  false
}

///|
/// The local UTC offset in seconds at a UNIX timestamp (unknown here, so
/// UTC).
pub fn local_offset(_timestamp : Int64) -> Int32 {
  0
}

///|
/// Whether two paths refer to the same file (the `same-file` crate's
/// `is_same_file`). The host does not tell devices and inodes, so the
/// paths are compared after `canonicalize`: links to one file are told
/// apart here. An error if one of them does not exist.
pub fn is_same_file(path1 : String, path2 : String) -> Bool raise IoError {
  canonicalize(path1) == canonicalize(path2)
}

///|
/// The `io::Error` for an OS error number of the host
/// (`io::Error::from_raw_os_error`). There is no `strerror` here: the
/// numbers that Linux and macOS share have their text, the others none.
pub fn os_error(code : Int32) -> IoError {
  let message = match code {
    1 => "Operation not permitted"
    2 => "No such file or directory"
    4 => "Interrupted system call"
    5 => "Input/output error"
    9 => "Bad file descriptor"
    12 => "Cannot allocate memory"
    13 => "Permission denied"
    17 => "File exists"
    20 => "Not a directory"
    21 => "Is a directory"
    22 => "Invalid argument"
    23 => "Too many open files in system"
    24 => "Too many open files"
    28 => "No space left on device"
    30 => "Read-only file system"
    _ => return IoError(kind_of_errno(code), "os error \{code}")
  }
  IoError(kind_of_errno(code), "\{message} (os error \{code})")
}

///|
/// A clock in nanoseconds for measuring durations (the wall clock here,
/// which the host only gives in milliseconds).
pub fn monotonic_nanos() -> Int64 {
  now_ms() * 1000000L
}

///|
/// Raises the soft limit of open file descriptors (not possible here: the
/// limit is the host's).
pub fn raise_fd_limit() -> Unit {

}

///|
/// The CPU architecture (Rust's `std::env::consts::ARCH`).
pub fn arch() -> String {
  "wasm32"
}

///|
/// Rust's `Debug` for an `io::Error` (approximated: the host's errno values
/// are not known here).
pub fn rust_debug(err : IoError) -> String {
  let IoError(_, text) = err
  "Custom { kind: \{kind_name(err.kind())}, error: \{rust_debug_str(text)} }"
}
