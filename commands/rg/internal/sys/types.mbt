///|
pub(all) enum Capability[T] {
  Available(T)
  Unavailable(String)
} derive(Debug, Eq)

///|
pub(all) enum FileType {
  File
  Dir
  Symlink
  Other
} derive(Debug, Eq)

///|
/// Information available from one directory visit. A non-directory entry
/// still needs a kind query: it can be a file, a link, or a special entry.
#valtype
pub struct DirEntry {
  name : String
  priv is_dir : Bool
}

///|
pub(all) struct Metadata {
  file_type : FileType
  len : Int64
} derive(Debug, Eq)

///|
pub fn Metadata::is_file(self : Metadata) -> Bool {
  self.file_type is File
}

///|
pub fn Metadata::is_dir(self : Metadata) -> Bool {
  self.file_type is Dir
}

///|
pub(all) struct FileTimes {
  modified : Int64?
  accessed : Int64?
  created : Int64?
} derive(Debug, Eq)

///|
pub struct File {
  priv inner : @fs.File
}

///|
pub(all) enum IOErrorKind {
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
} derive(Debug, Eq)

///|
pub suberror IOError {
  IOError(kind~ : IOErrorKind, code~ : Int32, message~ : String)
} derive(Debug)

///|
pub fn IOError::kind(self : IOError) -> IOErrorKind {
  let IOError(kind~, ..) = self
  kind
}

///|
fn IOError::code(self : IOError) -> Int32 {
  let IOError(code~, ..) = self
  code
}

///|
fn IOError::message(self : IOError) -> String {
  let IOError(message~, ..) = self
  message
}

///|
pub fn IOError::to_string(self : IOError) -> String {
  if self.code() >= 0 {
    "\{self.message()} (os error \{self.code()})"
  } else {
    self.message()
  }
}

///|
pub impl Show for IOError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub fn IOError::other(kind : IOErrorKind, message : String) -> IOError {
  IOError(kind~, code=-1, message~)
}

///|
/// Logical errno requests are synthetic errors, never fabricated host errno data.
pub fn IOError::from_errno(code : Int32) -> IOError {
  let (kind, message) = match code {
    2 => (NotFound, "No such file or directory")
    20 => (NotADirectory, "Not a directory")
    40 => (Other, "Too many levels of symbolic links")
    _ => (Other, "I/O operation failed")
  }
  IOError(kind~, code~, message~)
}

///|
pub fn from_error(error : Error) -> IOError {
  match error {
    IOError(..) as e => e
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
      IOError(kind~, code=-1, message=e.to_string())
    }
    _ => IOError::other(Other, error.to_string())
  }
}

///|
fn io_error(error : Error) -> IOError {
  from_error(error)
}
