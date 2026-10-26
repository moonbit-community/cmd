///|
/// The kind of error that can occur when parsing a glob pattern.
pub(all) enum ErrorKind {
  /// **DEPRECATED**.
  ///
  /// This error used to occur for consistency with git's glob specification,
  /// but the specification now accepts all uses of `**`. When `**` does not
  /// appear adjacent to a path separator or at the beginning/end of a glob,
  /// it is now treated as two consecutive `*` patterns. As such, this error
  /// is no longer used.
  InvalidRecursive
  /// Occurs when a character class (e.g., `[abc]`) is not closed.
  UnclosedClass
  /// Occurs when a range in a character (e.g., `[a-z]`) is invalid. For
  /// example, if the range starts with a lexicographically larger character
  /// than it ends with.
  InvalidRange(Char, Char)
  /// Occurs when a `}` is found without a matching `{`.
  UnopenedAlternates
  /// Occurs when a `{` is found without a matching `}`.
  UnclosedAlternates
  /// **DEPRECATED**.
  ///
  /// This error used to occur when an alternating group was nested inside
  /// another alternating group, e.g., `{{a,b},{c,d}}`. However, this is now
  /// supported and as such this error cannot occur.
  NestedAlternates
  /// Occurs when an unescaped '\' is found at the end of a glob.
  DanglingEscape
  /// An error associated with parsing or compiling a regex.
  Regex(String)
} derive(Eq, Debug)

///|
fn ErrorKind::description(self : ErrorKind) -> String {
  match self {
    InvalidRecursive => "invalid use of **; must be one path component"
    UnclosedClass => "unclosed character class; missing ']'"
    InvalidRange(_, _) => "invalid character range"
    UnopenedAlternates =>
      "unopened alternate group; missing '{' (maybe escape '}' with '[}]'?)"
    UnclosedAlternates =>
      "unclosed alternate group; missing '}' (maybe escape '{' with '[{]'?)"
    NestedAlternates => "nested alternate groups are not allowed"
    DanglingEscape => "dangling '\\'"
    Regex(err) => err
  }
}

///|
pub impl Show for ErrorKind with fn output(self, logger) {
  match self {
    InvalidRange(s, e) => logger.write_string("invalid range; '\{s}' > '\{e}'")
    _ => logger.write_string(self.description())
  }
}

///|
pub fn ErrorKind::to_string(self : ErrorKind) -> String {
  Show::to_string(self)
}

///|
/// Represents an error that can occur when parsing a glob pattern.
pub suberror GlobError {
  GlobError(glob~ : String?, kind~ : ErrorKind)
} derive(Eq, Debug)

///|
/// Return the glob that caused this error, if one exists.
pub fn GlobError::glob(self : GlobError) -> String? {
  let GlobError(glob~, ..) = self
  glob
}

///|
/// Return the kind of this error.
pub fn GlobError::kind(self : GlobError) -> ErrorKind {
  let GlobError(kind~, ..) = self
  kind
}

///|
pub impl Show for GlobError with fn output(self, logger) {
  let GlobError(glob~, kind~) = self
  match glob {
    None => logger.write_string(kind.to_string())
    Some(glob) =>
      logger.write_string("error parsing glob '\{glob}': \{kind.to_string()}")
  }
}

///|
pub fn GlobError::to_string(self : GlobError) -> String {
  Show::to_string(self)
}
