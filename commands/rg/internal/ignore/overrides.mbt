// Port of `ignore/src/overrides.rs`.
//
// The overrides module provides a way to specify a set of override globs.
// This provides functionality similar to `--include` or `--exclude` in
// command line tools.

///|
/// A single glob in an override matcher (Rust's
/// `ignore::overrides::Glob`).
///
/// This is used to report information about the highest precedent glob
/// that matched.
///
/// Note that not all matches necessarily correspond to a specific glob. For
/// example, if there are one or more whitelist globs and a file path doesn't
/// match any glob in the set, then the file path is considered to be ignored.
pub(all) enum OverrideGlob {
  /// No glob matched, but the file path should still be ignored.
  UnmatchedIgnore
  /// A glob matched.
  Matched(GitignoreGlob)
} derive(Debug)

///|
/// Manages a set of overrides provided explicitly by the end user.
pub struct Override {
  priv gi : Gitignore
} derive(Debug)

///|
/// Returns an empty matcher that never matches any file path.
pub fn Override::empty() -> Override {
  { gi: Gitignore::empty(), }
}

///|
/// Returns the directory of this override set.
///
/// All matches are done relative to this path.
pub fn Override::path(self : Override) -> String {
  self.gi.path()
}

///|
/// Returns true if and only if this matcher is empty.
///
/// When a matcher is empty, it will never match any file path.
pub fn Override::is_empty(self : Override) -> Bool {
  self.gi.is_empty()
}

///|
/// Returns the total number of ignore globs.
pub fn Override::num_ignores(self : Override) -> Int32 {
  self.gi.num_whitelists()
}

///|
/// Returns the total number of whitelisted globs.
pub fn Override::num_whitelists(self : Override) -> Int32 {
  self.gi.num_ignores()
}

///|
/// Returns whether the given file path matched a pattern in this override
/// matcher.
///
/// `is_dir` should be true if the path refers to a directory and false
/// otherwise.
///
/// If there are no overrides, then this always returns `Match::None`.
///
/// If there is at least one whitelist override and `is_dir` is false, then
/// this never returns `Match::None`, since non-matches are interpreted as
/// ignored.
///
/// The given path is matched to the globs relative to the path given
/// when building the override matcher. Specifically, before matching
/// `path`, its prefix (as determined by a common suffix of the directory
/// given) is stripped. If there is no common suffix/prefix overlap, then
/// `path` is assumed to reside in the same directory as the root path for
/// this set of overrides.
pub fn Override::matched(
  self : Override,
  path : String,
  is_dir : Bool,
) -> Match[OverrideGlob] {
  if self.is_empty() {
    return None
  }
  let mat = self.gi.matched(path, is_dir).invert()
  if mat.is_none() && self.num_whitelists() > 0 && !is_dir {
    return Ignore(UnmatchedIgnore)
  }
  mat.map(giglob => Matched(giglob))
}

///|
/// Builds a matcher for a set of glob overrides.
pub struct OverrideBuilder {
  priv builder : GitignoreBuilder
}

///|
/// Create a new override builder.
///
/// Matching is done relative to the directory path provided.
pub fn OverrideBuilder::new(path : String) -> OverrideBuilder {
  let builder = GitignoreBuilder::new(path)
  builder.allow_unclosed_class(false) |> ignore
  { builder, }
}

///|
/// Builds a new override matcher from the globs added so far.
///
/// Once a matcher is built, no new globs can be added to it.
pub fn OverrideBuilder::build(
  self : OverrideBuilder,
) -> Override raise IgnoreError {
  { gi: self.builder.build(), }
}

///|
/// Add a glob to the set of overrides.
///
/// Globs provided here have precisely the same semantics as a single
/// line in a `gitignore` file, where the meaning of `!` is inverted:
/// namely, `!` at the beginning of a glob will ignore a file. Without `!`,
/// all matches of the glob provided are treated as whitelist matches.
pub fn OverrideBuilder::add(
  self : OverrideBuilder,
  glob : String,
) -> OverrideBuilder raise IgnoreError {
  self.builder.add_line(None, glob) |> ignore
  self
}

///|
/// Toggle whether the globs should be matched case insensitively or not.
///
/// When this option is changed, only globs added after the change will be
/// affected.
///
/// This is disabled by default.
pub fn OverrideBuilder::case_insensitive(
  self : OverrideBuilder,
  yes : Bool,
) -> OverrideBuilder {
  self.builder.case_insensitive(yes) |> ignore
  self
}

///|
/// Toggle whether unclosed character classes are allowed. When allowed,
/// a `[` without a matching `]` is treated literally instead of resulting
/// in a parse error.
///
/// By default, this is false (unlike `Gitignore`, which follows git's
/// behavior).
pub fn OverrideBuilder::allow_unclosed_class(
  self : OverrideBuilder,
  yes : Bool,
) -> OverrideBuilder {
  self.builder.allow_unclosed_class(yes) |> ignore
  self
}
