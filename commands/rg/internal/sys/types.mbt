///|
#derive(Debug, Eq)
pub(all) enum Capability[T] {
  Available(T)
  Unavailable(String)
}

///|
#derive(Debug, Eq)
pub(all) enum FileType {
  File
  Dir
  Symlink
  Other
}

///|
/// Information available from one directory visit. A non-directory entry
/// still needs a kind query: it can be a file, a link, or a special entry.
#valtype
pub struct DirEntry {
  name : String
  priv is_dir : Bool
}

///|
#derive(Debug, Eq)
pub(all) struct Metadata {
  file_type : FileType
  len : Int64
}

///|
pub fn Metadata::is_file(self : Metadata) -> Bool {
  self.file_type is File
}

///|
pub fn Metadata::is_dir(self : Metadata) -> Bool {
  self.file_type is Dir
}

///|
#derive(Debug, Eq)
pub(all) struct FileTimes {
  modified : Int64?
  accessed : Int64?
  created : Int64?
}

///|
pub struct File {
  priv inner : @fs.File
}

///|
#derive(Debug, Eq)
pub(all) enum IoErrorKind {
  NotFound
  PermissionDenied
  AlreadyExists
  InvalidInput
  Interrupted
  BrokenPipe
  IsADirectory
  NotADirectory
  Unsupported
  Other
}

///|
#derive(Debug)
pub suberror IoError {
  IoError(kind~ : IoErrorKind, code~ : Int32, message~ : String)
}

///|
pub fn IoError::kind(self : IoError) -> IoErrorKind {
  let IoError(kind~, ..) = self
  kind
}

///|
fn IoError::code(self : IoError) -> Int32 {
  let IoError(code~, ..) = self
  code
}

///|
fn IoError::message(self : IoError) -> String {
  let IoError(message~, ..) = self
  message
}

///|
pub fn IoError::to_string(self : IoError) -> String {
  if self.code() >= 0 {
    "\{self.message()} (os error \{self.code()})"
  } else {
    self.message()
  }
}

///|
pub impl Show for IoError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn IoError::other(kind : IoErrorKind, message : String) -> IoError {
  IoError(kind~, code=-1, message~)
}

///|
/// Logical errno requests are synthetic errors, never fabricated host errno data.
pub fn IoError::from_errno(code : Int32) -> IoError {
  let (kind, message) = match code {
    2 => (NotFound, "No such file or directory")
    20 => (NotADirectory, "Not a directory")
    40 => (Other, "Too many levels of symbolic links")
    _ => (Other, "I/O operation failed")
  }
  IoError(kind~, code~, message~)
}

///|
pub fn from_error(error : Error) -> IoError {
  match error {
    IoError(..) as e => e
    @core_os.OsError(kind, raw_code=code, ..) as e => {
      let kind = match kind {
        NotFound => NotFound
        AccessDenied => PermissionDenied
        AlreadyExists => AlreadyExists
        NotDirectory => NotADirectory
        _ if !is_windows() && code == 4 => Interrupted
        _ if !is_windows() && code == 21 => IsADirectory
        _ if !is_windows() && code == 32 => BrokenPipe
        _ => Other
      }
      IoError(kind~, code=-1, message=e.to_string())
    }
    @os_error.OSError(code, ..) as e => {
      let kind = if e.is_ENOENT() {
        NotFound
      } else if e.is_EACCES() {
        PermissionDenied
      } else if e.is_EEXIST() {
        AlreadyExists
      } else if e.is_EINTR() {
        Interrupted
      } else if e.is_ENOTDIR() {
        NotADirectory
      } else if code == 21 && !is_windows() {
        IsADirectory
      } else if code == 32 && !is_windows() {
        BrokenPipe
      } else {
        Other
      }
      IoError(kind~, code=-1, message=e.to_string())
    }
    _ => IoError::other(Other, error.to_string())
  }
}
