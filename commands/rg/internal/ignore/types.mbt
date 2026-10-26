// Port of `ignore/src/types.rs`.
//
// The types module provides a way of associating globs on file names to file
// types.
//
// This can be used to match specific types of files. For example, among
// the default file types provided, the Rust file type is defined to be
// `*.rs` with name `rust`. Similarly, the C file type is defined to be
// `*.{c,h}` with name `c`.

///|
/// A single glob in a set of file type definitions (Rust's
/// `ignore::types::Glob`).
///
/// Note that not all matches necessarily correspond to a specific glob.
/// For example, if there are one or more selections and a file path doesn't
/// match any of those selections, then the file path is considered to be
/// ignored.
pub(all) enum TypesGlob {
  /// No glob matched, but the file path should still be ignored.
  UnmatchedIgnore
  /// A glob matched.
  Matched(def~ : FileTypeDef)
} derive(Debug)

///|
/// Return the file type definition that matched, if one exists. A file type
/// definition always exists when a specific definition matches a file
/// path.
pub fn TypesGlob::file_type_def(self : TypesGlob) -> FileTypeDef? {
  match self {
    UnmatchedIgnore => None
    Matched(def~) => Some(def)
  }
}

///|
/// A single file type definition.
///
/// File type definitions can be retrieved in aggregate from a file type
/// matcher. File type definitions are also reported when its responsible
/// for a match.
pub struct FileTypeDef {
  priv name : String
  priv globs : Array[String]
} derive(Debug, Eq)

///|
/// Return the name of this file type.
pub fn FileTypeDef::name(self : FileTypeDef) -> String {
  self.name
}

///|
/// Return the globs used to recognize this file type.
pub fn FileTypeDef::globs(self : FileTypeDef) -> ArrayView[String] {
  self.globs
}

///|
fn FileTypeDef::clone(self : FileTypeDef) -> FileTypeDef {
  { name: self.name, globs: self.globs.copy(), }
}

///|
/// Indicates the type of a selection for a particular file type.
priv enum Selection[T] {
  Select(String, T)
  Negate(String, T)
} derive(Debug)

///|
fn[T] Selection::is_negated(self : Selection[T]) -> Bool {
  self is Negate(_, _)
}

///|
fn[T] Selection::name(self : Selection[T]) -> String {
  match self {
    Select(name, _) | Negate(name, _) => name
  }
}

///|
fn[T, U] Selection::map(self : Selection[T], f : (T) -> U) -> Selection[U] {
  match self {
    Select(name, inner) => Select(name, f(inner))
    Negate(name, inner) => Negate(name, f(inner))
  }
}

///|
fn[T] Selection::inner(self : Selection[T]) -> T {
  match self {
    Select(_, inner) | Negate(_, inner) => inner
  }
}

///|
/// Types is a file type matcher.
pub struct Types {
  /// All of the file type definitions, sorted lexicographically by name.
  priv defs : Array[FileTypeDef]
  /// All of the selections made by the user.
  priv selections : Array[Selection[FileTypeDef]]
  /// Whether there is at least one Selection::Select in our selections.
  /// When this is true, a Match::None is converted to Match::Ignore.
  priv has_selected : Bool
  /// A mapping from glob index in the set to two indices. The first is an
  /// index into `selections` and the second is an index into the
  /// corresponding file type definition's list of globs.
  priv glob_to_selection : Array[(Int32, Int32)]
  /// The set of all glob selections, used for actual matching.
  priv set : @globset.GlobSet
  /// Temporary storage for globs that match.
  priv matches : Array[Int32]
}

///|
pub impl Debug for Types with fn to_repr(self) {
  @debug.Repr::record({
    "defs": Debug::to_repr(self.defs),
    "selections": Debug::to_repr(self.selections),
    "has_selected": Debug::to_repr(self.has_selected),
  })
}

///|
/// Creates a new file type matcher that never matches any path and
/// contains no file type definitions.
pub fn Types::empty() -> Types {
  {
    defs: [],
    selections: [],
    has_selected: false,
    glob_to_selection: [],
    set: @globset.GlobSet::empty(),
    matches: [],
  }
}

///|
/// Returns true if and only if this matcher has zero selections.
pub fn Types::is_empty(self : Types) -> Bool {
  self.selections.is_empty()
}

///|
/// Returns the number of selections used in this matcher.
pub fn Types::len(self : Types) -> Int32 {
  self.selections.length()
}

///|
/// Return the set of current file type definitions.
///
/// Definitions and globs are sorted.
pub fn Types::definitions(self : Types) -> ArrayView[FileTypeDef] {
  self.defs
}

///|
/// Returns a match for the given path against this file type matcher.
///
/// The path is considered whitelisted if it matches a selected file type.
/// The path is considered ignored if it matches a negated file type.
/// If at least one file type is selected and `path` doesn't match, then
/// the path is also considered ignored.
pub fn Types::matched(
  self : Types,
  path : String,
  is_dir : Bool,
) -> Match[TypesGlob] {
  // File types don't apply to directories, and we can't do anything
  // if our glob set is empty.
  if is_dir || self.set.is_empty() {
    return None
  }
  // We only want to match against the file name, so extract it.
  // If one doesn't exist, then we can't match it.
  let name = match file_name(path) {
    Some(name) => name
    None if self.has_selected => return Ignore(UnmatchedIgnore)
    None => return None
  }
  let matches = self.matches
  self.set.matches_into(name, matches)
  // The highest precedent match is the last one.
  if matches.last() is Some(i) {
    let (isel, _) = self.glob_to_selection[i]
    let sel = self.selections[isel]
    let glob = TypesGlob::Matched(def=sel.inner())
    return if sel.is_negated() { Ignore(glob) } else { Whitelist(glob) }
  }
  if self.has_selected {
    Ignore(UnmatchedIgnore)
  } else {
    None
  }
}

///|
/// TypesBuilder builds a type matcher from a set of file type definitions
/// and a set of file type selections.
pub struct TypesBuilder {
  priv types : Map[String, FileTypeDef]
  priv selections : Array[Selection[Unit]]
}

///|
/// Create a new builder for a file type matcher.
///
/// The builder contains *no* type definitions to start with. A set
/// of default type definitions can be added with `add_defaults`, and
/// additional type definitions can be added with `select` and `negate`.
pub fn TypesBuilder::new() -> TypesBuilder {
  { types: {}, selections: [], }
}

///|
/// Build the current set of file type definitions *and* selections into
/// a file type matcher.
pub fn TypesBuilder::build(self : TypesBuilder) -> Types raise IgnoreError {
  let defs = self.definitions()
  let has_selected = self.selections.iter().any(s => !s.is_negated())
  let selections = []
  let glob_to_selection = []
  let build_set = @globset.GlobSetBuilder::new()
  for isel, selection in self.selections {
    let def = match self.types.get(selection.name()) {
      Some(def) => def.clone()
      None => raise UnrecognizedFileType(selection.name())
    }
    for iglob, glob in def.globs {
      let g = @globset.GlobBuilder::new(glob).literal_separator(true).build() catch {
          err => raise Glob(glob=Some(glob), err=err.kind().to_string())
        }
      build_set.add(g) |> ignore
      glob_to_selection.push((isel, iglob))
    }
    selections.push(selection.map(_ => def))
  }
  let set = build_set.build() catch {
    err => raise Glob(glob=None, err=err.to_string())
  }
  { defs, selections, has_selected, glob_to_selection, set, matches: [], }
}

///|
/// Return the set of current file type definitions.
///
/// Definitions and globs are sorted.
pub fn TypesBuilder::definitions(self : TypesBuilder) -> Array[FileTypeDef] {
  let defs = []
  for _, def in self.types {
    let def = def.clone()
    def.globs.sort_by(compare_utf8)
    defs.push(def)
  }
  defs.sort_by((a, b) => compare_utf8(a.name, b.name))
  defs
}

///|
/// Select the file type given by `name`.
///
/// If `name` is `all`, then all file types currently defined are selected.
pub fn TypesBuilder::select(self : TypesBuilder, name : String) -> TypesBuilder {
  if name == "all" {
    for name, _ in self.types {
      self.selections.push(Select(name, ()))
    }
  } else {
    self.selections.push(Select(name, ()))
  }
  self
}

///|
/// Ignore the file type given by `name`.
///
/// If `name` is `all`, then all file types currently defined are negated.
pub fn TypesBuilder::negate(self : TypesBuilder, name : String) -> TypesBuilder {
  if name == "all" {
    for name, _ in self.types {
      self.selections.push(Negate(name, ()))
    }
  } else {
    self.selections.push(Negate(name, ()))
  }
  self
}

///|
/// Clear any file type definitions for the type name given.
pub fn TypesBuilder::clear(self : TypesBuilder, name : String) -> TypesBuilder {
  self.types.remove(name)
  self
}

///|
/// Add a new file type definition. `name` can be arbitrary and `pat`
/// should be a glob recognizing file paths belonging to the `name` type.
///
/// If `name` is `all` or otherwise contains any character that is not a
/// Unicode letter or number, then an error is returned.
pub fn TypesBuilder::add(
  self : TypesBuilder,
  name : String,
  glob : String,
) -> Unit raise IgnoreError {
  if name == "all" || !name.iter().all(is_alphanumeric) {
    raise InvalidDefinition
  }
  match self.types.get(name) {
    Some(def) => def.globs.push(glob)
    None => self.types[name] = { name, globs: [glob], }
  }
}

///|
/// Add a new file type definition specified in string form. There are two
/// valid formats:
/// 1. `{name}:{glob}`. This defines a 'root' definition that associates the
///    given name with the given glob.
/// 2. `{name}:include:{comma-separated list of already defined names}`.
///    This defines an 'include' definition that associates the given name
///    with the definitions of the given existing types.
///
/// Names may not include any characters that are not Unicode letters or
/// numbers.
pub fn TypesBuilder::add_def(
  self : TypesBuilder,
  def : String,
) -> Unit raise IgnoreError {
  let parts = def.split(":").map(v => v.to_owned()).collect()
  match parts.length() {
    2 => {
      let name = parts[0]
      let glob = parts[1]
      if name == "" || glob == "" {
        raise InvalidDefinition
      }
      self.add(name, glob)
    }
    3 => {
      let name = parts[0]
      let types_string = parts[2]
      if name == "" || parts[1] != "include" || types_string == "" {
        raise InvalidDefinition
      }
      let types = types_string.split(",").map(v => v.to_owned()).collect()
      // Check ahead of time to ensure that all types specified are
      // present and fail fast if not.
      if types.iter().any(t => !self.types.contains(t)) {
        raise InvalidDefinition
      }
      for type_name in types {
        let globs = self.types[type_name].globs.copy()
        for glob in globs {
          self.add(name, glob)
        }
      }
    }
    _ => raise InvalidDefinition
  }
}

///|
/// Add a set of default file type definitions.
pub fn TypesBuilder::add_defaults(self : TypesBuilder) -> TypesBuilder {
  for entry in default_types() {
    let (names, exts) = entry
    for name in names {
      for ext in exts {
        self.add(name, ext) catch {
          _ => abort("adding a default type should never fail")
        }
      }
    }
  }
  self
}

///|
/// Like Rust's `char::is_alphanumeric`, with the Unicode version of the Rust
/// toolchain that builds ripgrep (see `alphanumeric_ranges`).
fn is_alphanumeric(c : Char) -> Bool {
  let x = c.to_int()
  let r = alphanumeric_ranges
  let mut lo = 0
  let mut hi = r.length() / 2
  while lo < hi {
    let mid = (lo + hi) / 2
    if x < r[2 * mid] {
      hi = mid
    } else if x > r[2 * mid + 1] {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}
