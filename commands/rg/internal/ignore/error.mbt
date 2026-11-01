///|
fn from_async_error(error : Error) -> IgnoreError {
  match error {
    Partial(errors) => Partial(errors)
    WithLineNumber(line~, err~) => WithLineNumber(line~, err~)
    WithPath(path~, err~) => WithPath(path~, err~)
    WithDepth(depth~, err~) => WithDepth(depth~, err~)
    Loop(ancestor~, child~) => Loop(ancestor~, child~)
    Io(error) => Io(error)
    Glob(glob~, err~) => Glob(glob~, err~)
    UnrecognizedFileType(name) => UnrecognizedFileType(name)
    InvalidDefinition => InvalidDefinition
    _ => Io(@sys.from_error(error))
  }
}

///|
/// Represents an error that can occur when parsing a gitignore file or when
/// walking a directory tree.
///
/// This is a port of Rust's `ignore::Error`. Its `to_string()` rendering is
/// identical to the Rust `Display` implementation.
pub(all) suberror IgnoreError {
  /// A collection of "soft" errors. These occur when adding an ignore
  /// file partially succeeded.
  Partial(Array[IgnoreError])
  /// An error associated with a specific line number.
  WithLineNumber(line~ : Int32, err~ : IgnoreError)
  /// An error associated with a particular file path.
  WithPath(path~ : String, err~ : IgnoreError)
  /// An error associated with a particular directory depth when recursively
  /// walking a directory.
  WithDepth(depth~ : Int32, err~ : IgnoreError)
  /// An error that occurs when a file loop is detected when traversing
  /// symbolic links.
  Loop(ancestor~ : String, child~ : String)
  /// An error that occurs when doing I/O, such as reading an ignore file.
  Io(@sys.IOError)
  /// An error that occurs when trying to parse a glob. `glob` is the
  /// original glob as written by the end user (when available) and `err` is
  /// the underlying glob error rendered as a string.
  Glob(glob~ : String?, err~ : String)
  /// A type selection for a file type that is not defined.
  UnrecognizedFileType(String)
  /// A user specified file type definition could not be parsed.
  InvalidDefinition
} derive(Debug)

///|
/// Returns true if this error is exclusively an I/O error.
fn IgnoreError::is_io(self : IgnoreError) -> Bool {
  match self {
    Partial(errs) => errs.length() == 1 && errs[0].is_io()
    WithLineNumber(err~, ..) | WithPath(err~, ..) | WithDepth(err~, ..) =>
      err.is_io()
    Io(_) => true
    Loop(..) | Glob(..) | UnrecognizedFileType(_) | InvalidDefinition => false
  }
}

///|
/// Turn an error into a tagged error with the given file path.
fn IgnoreError::with_path(self : IgnoreError, path : String) -> IgnoreError {
  WithPath(path~, err=self)
}

///|
/// Turn an error into a tagged error with the given depth.
fn IgnoreError::with_depth(self : IgnoreError, depth : Int32) -> IgnoreError {
  WithDepth(depth~, err=self)
}

///|
/// Turn an error into a tagged error with the given file path and line
/// number. If path is empty, then it is omitted from the error.
fn IgnoreError::tagged(
  self : IgnoreError,
  path : String,
  lineno : Int32,
) -> IgnoreError {
  let errline = WithLineNumber(line=lineno, err=self)
  if path == "" {
    return errline
  }
  errline.with_path(path)
}

///|
/// Renders this error exactly like Rust's `Display` for `ignore::Error`.
pub fn IgnoreError::to_string(self : IgnoreError) -> String {
  let sb = StringBuilder()
  self.write_to(sb)
  sb.to_string()
}

///|
fn IgnoreError::write_to(self : IgnoreError, sb : StringBuilder) -> Unit {
  match self {
    Partial(errs) =>
      for i, err in errs {
        if i > 0 {
          sb.write_char('\n')
        }
        err.write_to(sb)
      }
    WithLineNumber(line~, err~) => {
      sb.write_string("line \{line}: ")
      err.write_to(sb)
    }
    WithPath(path~, err~) => {
      sb.write_string(path)
      sb.write_string(": ")
      err.write_to(sb)
    }
    WithDepth(err~, ..) => err.write_to(sb)
    Loop(ancestor~, child~) =>
      sb.write_string(
        "File system loop found: \{child} points to an ancestor \{ancestor}",
      )
    Io(err) => sb.write_string(Show::to_string(err))
    Glob(glob=None, err~) => sb.write_string(err)
    Glob(glob=Some(glob), err~) =>
      sb.write_string("error parsing glob '\{glob}': \{err}")
    UnrecognizedFileType(ty) => sb.write_string("unrecognized file type: \{ty}")
    InvalidDefinition =>
      sb.write_string(
        "invalid definition (format is type:glob, e.g., html:*.html)",
      )
  }
}

///|
pub impl Show for IgnoreError with fn output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Accumulates "soft" errors.
priv struct PartialErrorBuilder(Array[IgnoreError])

///|
fn PartialErrorBuilder::new() -> PartialErrorBuilder {
  PartialErrorBuilder([])
}

///|
fn PartialErrorBuilder::push(
  self : PartialErrorBuilder,
  err : IgnoreError,
) -> Unit {
  self.0.push(err)
}

///|
fn PartialErrorBuilder::push_ignore_io(
  self : PartialErrorBuilder,
  err : IgnoreError,
) -> Unit {
  if !err.is_io() {
    self.push(err)
  }
}

///|
fn PartialErrorBuilder::maybe_push(
  self : PartialErrorBuilder,
  err : IgnoreError?,
) -> Unit {
  if err is Some(err) {
    self.push(err)
  }
}

///|
fn PartialErrorBuilder::maybe_push_ignore_io(
  self : PartialErrorBuilder,
  err : IgnoreError?,
) -> Unit {
  if err is Some(err) {
    self.push_ignore_io(err)
  }
}

///|
fn PartialErrorBuilder::into_error_option(
  self : PartialErrorBuilder,
) -> IgnoreError? {
  if self.0.is_empty() {
    None
  } else if self.0.length() == 1 {
    Some(self.0[0])
  } else {
    Some(Partial(self.0))
  }
}

///|
/// The result of a glob match.
///
/// The type parameter `T` typically refers to a type that provides more
/// information about a particular match. For example, it might identify
/// the specific gitignore file and the specific glob pattern that caused
/// the match.
pub(all) enum Match[T] {
  /// The path didn't match any glob.
  None
  /// The highest precedent glob matched indicates the path should be
  /// ignored.
  Ignore(T)
  /// The highest precedent glob matched indicates the path should be
  /// whitelisted.
  Whitelist(T)
} derive(Debug)

///|
/// Returns true if the match result didn't match any globs.
pub fn[T] Match::is_none(self : Match[T]) -> Bool {
  self is None
}

///|
/// Returns true if the match result implies the path should be ignored.
pub fn[T] Match::is_ignore(self : Match[T]) -> Bool {
  self is Ignore(_)
}

///|
/// Returns true if the match result implies the path should be
/// whitelisted.
pub fn[T] Match::is_whitelist(self : Match[T]) -> Bool {
  self is Whitelist(_)
}

///|
/// Inverts the match so that `Ignore` becomes `Whitelist` and
/// `Whitelist` becomes `Ignore`. A non-match remains the same.
pub fn[T] Match::invert(self : Match[T]) -> Match[T] {
  match self {
    None => None
    Ignore(t) => Whitelist(t)
    Whitelist(t) => Ignore(t)
  }
}

///|
/// Return the value inside this match if it exists.
pub fn[T] Match::inner(self : Match[T]) -> T? {
  match self {
    None => Option::None
    Ignore(t) | Whitelist(t) => Some(t)
  }
}

///|
/// Apply the given function to the value inside this match.
///
/// If the match has no value, then return the match unchanged.
pub fn[T, U] Match::map(self : Match[T], f : (T) -> U) -> Match[U] {
  match self {
    None => None
    Ignore(t) => Ignore(f(t))
    Whitelist(t) => Whitelist(f(t))
  }
}

///|
/// Return the match if it is not none. Otherwise, return other.
pub fn[T] Match::or(self : Match[T], other : Match[T]) -> Match[T] {
  if self.is_none() {
    other
  } else {
    self
  }
}
