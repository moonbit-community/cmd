///|
/// Returns a strategic matcher.
///
/// This isn't exposed because it's not clear whether it's actually
/// faster than just running a regex for a *single* pattern. If it
/// is faster, then GlobMatcher should do it automatically.
fn Glob::compile_strategic_matcher(self : Glob) -> GlobStrategic {
  let strategy = MatchStrategy::new(self)
  let re = new_regex(self.re) catch {
    e => abort("regex compilation shouldn't fail: \{e}")
  }
  { strategy, re, }
}

///|
/// A strategic matcher for a single pattern. Only used for testing.
priv struct GlobStrategic {
  /// The match strategy to use.
  strategy : MatchStrategy
  /// The pattern, as a compiled regex.
  re : @regex.Regex
}

///|
/// Tests whether the given path matches this pattern or not.
fn GlobStrategic::is_match(self : GlobStrategic, path : String) -> Bool {
  self.is_match_candidate(Candidate::new(path))
}

///|
/// Tests whether the given path matches this pattern or not.
fn GlobStrategic::is_match_candidate(
  self : GlobStrategic,
  candidate : Candidate,
) -> Bool {
  let byte_path = candidate.path
  match self.strategy {
    Literal(lit) => @utf8.encode(lit) == byte_path
    BasenameLiteral(lit) => @utf8.encode(lit) == candidate.basename
    Extension(ext) => @utf8.encode(ext) == candidate.ext
    Prefix(pre) => starts_with(@utf8.encode(pre), byte_path)
    Suffix(suffix~, component~) => {
      let suffix = @utf8.encode(suffix)
      if component && byte_path == suffix[1:].to_owned() {
        return true
      }
      ends_with(suffix, byte_path)
    }
    RequiredExtension(ext) =>
      candidate.ext == @utf8.encode(ext) &&
      regex_is_match(self.re, candidate.path_arr)
    Regex => regex_is_match(self.re, candidate.path_arr)
  }
}

///|
fn starts_with(needle : Bytes, haystack : Bytes) -> Bool {
  needle.length() <= haystack.length() &&
  needle == haystack[:needle.length()].to_owned()
}

///|
fn ends_with(needle : Bytes, haystack : Bytes) -> Bool {
  if needle.length() > haystack.length() {
    return false
  }
  needle == haystack[haystack.length() - needle.length():].to_owned()
}
