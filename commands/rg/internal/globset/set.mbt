///|
/// GlobSet represents a group of globs that can be matched together in a
/// single pass.
pub struct GlobSet {
  priv len : Int32
  priv strats : Array[GlobSetMatchStrategy]
}

///|
/// Create a new [`GlobSetBuilder`]. A `GlobSetBuilder` can be used to add
/// new patterns. Once all patterns have been added, `build` should be
/// called to produce a `GlobSet`, which can then be used for matching.
pub fn GlobSet::builder() -> GlobSetBuilder {
  GlobSetBuilder::new()
}

///|
/// Create an empty `GlobSet`. An empty set matches nothing.
pub fn GlobSet::empty() -> GlobSet {
  { len: 0, strats: [], }
}

///|
pub impl Default for GlobSet with fn default() {
  GlobSet::empty()
}

///|
/// Returns true if this set is empty, and therefore matches nothing.
pub fn GlobSet::is_empty(self : GlobSet) -> Bool {
  self.len == 0
}

///|
/// Returns the number of globs in this set.
pub fn GlobSet::len(self : GlobSet) -> Int32 {
  self.len
}

///|
/// Returns true if any glob in this set matches the path given.
pub fn GlobSet::is_match(self : GlobSet, path : String) -> Bool {
  self.is_match_candidate(Candidate::new(path))
}

///|
/// Returns true if any glob in this set matches the path given.
///
/// This takes a Candidate as input, which can be used to amortize the
/// cost of preparing a path for matching.
pub fn GlobSet::is_match_candidate(self : GlobSet, path : Candidate) -> Bool {
  if self.is_empty() {
    return false
  }
  for strat in self.strats {
    if strat.is_match(path) {
      return true
    }
  }
  false
}

///|
/// Returns true if all globs in this set match the path given.
///
/// This will return true if the set of globs is empty, as in that case all
/// `0` of the globs will match.
pub fn GlobSet::matches_all(self : GlobSet, path : String) -> Bool {
  self.matches_all_candidate(Candidate::new(path))
}

///|
/// Returns true if all globs in this set match the path given.
///
/// This takes a Candidate as input, which can be used to amortize the cost
/// of preparing a path for matching.
///
/// This will return true if the set of globs is empty, as in that case all
/// `0` of the globs will match.
pub fn GlobSet::matches_all_candidate(self : GlobSet, path : Candidate) -> Bool {
  for strat in self.strats {
    if !strat.matches_all(path) {
      return false
    }
  }
  true
}

///|
/// Returns the sequence number of every glob pattern that matches the
/// given path.
pub fn GlobSet::matches(self : GlobSet, path : String) -> Array[Int32] {
  self.matches_candidate(Candidate::new(path))
}

///|
/// Returns the sequence number of every glob pattern that matches the
/// given path.
///
/// This takes a Candidate as input, which can be used to amortize the
/// cost of preparing a path for matching.
pub fn GlobSet::matches_candidate(
  self : GlobSet,
  path : Candidate,
) -> Array[Int32] {
  let into = []
  if self.is_empty() {
    return into
  }
  self.matches_candidate_into(path, into)
  into
}

///|
/// Adds the sequence number of every glob pattern that matches the given
/// path to the array given.
///
/// `into` is cleared before matching begins, and contains the set of
/// sequence numbers (in ascending order) after matching ends. If no globs
/// were matched, then `into` will be empty.
pub fn GlobSet::matches_into(
  self : GlobSet,
  path : String,
  into : Array[Int32],
) -> Unit {
  self.matches_candidate_into(Candidate::new(path), into)
}

///|
/// Adds the sequence number of every glob pattern that matches the given
/// path to the array given.
///
/// `into` is cleared before matching begins, and contains the set of
/// sequence numbers (in ascending order) after matching ends. If no globs
/// were matched, then `into` will be empty.
///
/// This takes a Candidate as input, which can be used to amortize the
/// cost of preparing a path for matching.
pub fn GlobSet::matches_candidate_into(
  self : GlobSet,
  path : Candidate,
  into : Array[Int32],
) -> Unit {
  into.clear()
  if self.is_empty() {
    return
  }
  for strat in self.strats {
    strat.matches_into(path, into)
  }
  into.sort()
  into.dedup()
}

///|
/// Builds a new matcher from a collection of Glob patterns.
///
/// Once a matcher is built, no new patterns can be added to it.
pub fn GlobSet::new(globs : ArrayView[Glob]) -> GlobSet raise GlobError {
  if globs.is_empty() {
    return GlobSet::empty()
  }
  let mut len = 0
  let lits = LiteralStrategy::new()
  let base_lits = LiteralStrategy::new()
  let exts = LiteralStrategy::new()
  let prefixes = MultiStrategyBuilder::new()
  let suffixes = MultiStrategyBuilder::new()
  let required_exts : Map[Bytes, Array[(Int32, String)]] = Map([])
  let regexes = MultiStrategyBuilder::new()
  for i, p in globs {
    len += 1
    match MatchStrategy::new(p) {
      Literal(lit) => lits.add(i, lit)
      BasenameLiteral(lit) => base_lits.add(i, lit)
      Extension(ext) => exts.add(i, ext)
      Prefix(prefix) => prefixes.add(i, prefix)
      Suffix(suffix~, component~) => {
        if component {
          lits.add(i, suffix.view(start_offset=1).to_owned())
        }
        suffixes.add(i, suffix)
      }
      RequiredExtension(ext) => {
        let key = @utf8.encode(ext)
        match required_exts.get(key) {
          Some(entries) => entries.push((i, p.regex()))
          None => required_exts[key] = [(i, p.regex())]
        }
      }
      Regex => regexes.add(i, p.regex())
    }
  }
  let strats = []
  // Only add strategies that are populated
  if !exts.is_empty() {
    strats.push(GlobSetMatchStrategy::Extension(exts))
  }
  if !base_lits.is_empty() {
    strats.push(GlobSetMatchStrategy::BasenameLiteral(base_lits))
  }
  if !lits.is_empty() {
    strats.push(GlobSetMatchStrategy::Literal(lits))
  }
  if !suffixes.is_empty() {
    strats.push(GlobSetMatchStrategy::Suffix(suffixes.affix()))
  }
  if !prefixes.is_empty() {
    strats.push(GlobSetMatchStrategy::Prefix(prefixes.affix()))
  }
  if !required_exts.is_empty() {
    let compiled : Map[Bytes, Array[(Int32, @regex.Regex)]] = Map([])
    for ext, entries in required_exts {
      let res = []
      for entry in entries {
        let (global_index, regex) = entry
        res.push((global_index, new_regex(regex)))
      }
      compiled[ext] = res
    }
    strats.push(GlobSetMatchStrategy::RequiredExtension(compiled))
  }
  if !regexes.is_empty() {
    strats.push(GlobSetMatchStrategy::Regex(regexes.regex_set()))
  }
  { len, strats, }
}

///|
/// GlobSetBuilder builds a group of patterns that can be used to
/// simultaneously match a file path.
pub struct GlobSetBuilder {
  priv pats : Array[Glob]
} derive(Debug)

///|
/// Create a new `GlobSetBuilder`. A `GlobSetBuilder` can be used to add new
/// patterns. Once all patterns have been added, `build` should be called
/// to produce a [`GlobSet`], which can then be used for matching.
pub fn GlobSetBuilder::new() -> GlobSetBuilder {
  { pats: [], }
}

///|
/// Builds a new matcher from all of the glob patterns added so far.
///
/// Once a matcher is built, no new patterns can be added to it.
pub fn GlobSetBuilder::build(self : GlobSetBuilder) -> GlobSet raise GlobError {
  GlobSet::new(self.pats)
}

///|
/// Add a new pattern to this set.
pub fn GlobSetBuilder::add(self : GlobSetBuilder, pat : Glob) -> GlobSetBuilder {
  self.pats.push(pat)
  self
}

///|
priv enum GlobSetMatchStrategy {
  Literal(LiteralStrategy)
  BasenameLiteral(LiteralStrategy)
  Extension(LiteralStrategy)
  Prefix(AffixStrategy)
  Suffix(AffixStrategy)
  RequiredExtension(Map[Bytes, Array[(Int32, @regex.Regex)]])
  Regex(RegexSetStrategy)
}

///|
fn GlobSetMatchStrategy::is_match(
  self : GlobSetMatchStrategy,
  candidate : Candidate,
) -> Bool {
  match self {
    Literal(s) => s.is_match(candidate.path)
    BasenameLiteral(s) => s.is_match_nonempty(candidate.basename)
    Extension(s) => s.is_match_nonempty(candidate.ext)
    Prefix(s) => s.is_match(candidate.path, prefix=true)
    Suffix(s) => s.is_match(candidate.path, prefix=false)
    RequiredExtension(m) => required_ext_is_match(m, candidate)
    Regex(s) => s.is_match(candidate)
  }
}

///|
fn GlobSetMatchStrategy::matches_into(
  self : GlobSetMatchStrategy,
  candidate : Candidate,
  matches : Array[Int32],
) -> Unit {
  match self {
    Literal(s) => s.matches_into(candidate.path, matches)
    BasenameLiteral(s) =>
      if !candidate.basename.is_empty() {
        s.matches_into(candidate.basename, matches)
      }
    Extension(s) =>
      if !candidate.ext.is_empty() {
        s.matches_into(candidate.ext, matches)
      }
    Prefix(s) => s.matches_into(candidate.path, matches, prefix=true)
    Suffix(s) => s.matches_into(candidate.path, matches, prefix=false)
    RequiredExtension(m) => required_ext_matches_into(m, candidate, matches)
    Regex(s) => s.matches_into(candidate, matches)
  }
}

///|
fn GlobSetMatchStrategy::matches_all(
  self : GlobSetMatchStrategy,
  candidate : Candidate,
) -> Bool {
  match self {
    Literal(s) => s.matches_all(candidate.path)
    BasenameLiteral(s) => s.matches_all_nonempty(candidate.basename)
    Extension(s) => s.matches_all_nonempty(candidate.ext)
    Prefix(s) => s.matches_all(candidate.path, prefix=true)
    Suffix(s) => s.matches_all(candidate.path, prefix=false)
    RequiredExtension(m) => required_ext_matches_all(m, candidate)
    Regex(s) => s.matches_all(candidate)
  }
}

///|
/// Maps literal byte strings (whole paths, basenames or extensions) to the
/// indices of the globs that require exactly that literal.
priv struct LiteralStrategy {
  map : Map[Bytes, Array[Int32]]
}

///|
fn LiteralStrategy::new() -> LiteralStrategy {
  { map: {}, }
}

///|
fn LiteralStrategy::add(
  self : LiteralStrategy,
  global_index : Int32,
  lit : String,
) -> Unit {
  let key = @utf8.encode(lit)
  match self.map.get(key) {
    Some(hits) => hits.push(global_index)
    None => self.map[key] = [global_index]
  }
}

///|
fn LiteralStrategy::is_empty(self : LiteralStrategy) -> Bool {
  self.map.is_empty()
}

///|
fn LiteralStrategy::is_match(self : LiteralStrategy, key : Bytes) -> Bool {
  self.map.contains(key)
}

///|
fn LiteralStrategy::is_match_nonempty(
  self : LiteralStrategy,
  key : Bytes,
) -> Bool {
  if key.is_empty() {
    return false
  }
  self.map.contains(key)
}

///|
fn LiteralStrategy::matches_all(self : LiteralStrategy, key : Bytes) -> Bool {
  self.map.length() == 1 && self.is_match(key)
}

///|
fn LiteralStrategy::matches_all_nonempty(
  self : LiteralStrategy,
  key : Bytes,
) -> Bool {
  self.map.length() == 1 && self.is_match_nonempty(key)
}

///|
fn LiteralStrategy::matches_into(
  self : LiteralStrategy,
  key : Bytes,
  matches : Array[Int32],
) -> Unit {
  if self.map.get(key) is Some(hits) {
    matches.append(hits)
  }
}

///|
/// Matches a set of literal prefixes (or suffixes) against a path.
///
/// The Rust implementation uses Aho-Corasick over the first (or last)
/// `longest` bytes of the path and keeps only matches anchored at the
/// start (or end). This is equivalent to looking up, for every distinct
/// literal length `L`, the first (or last) `L` bytes of the path in a hash
/// table, which is what this strategy does.
priv struct AffixStrategy {
  /// Maps each literal to the global indices of the globs that use it.
  map : Map[Bytes, Array[Int32]]
  /// The distinct lengths of all literals, in ascending order.
  lens : Array[Int32]
  /// The total number of literals (including duplicates).
  count : Int32
}

///|
fn AffixStrategy::affix_of(
  path : Bytes,
  len : Int32,
  prefix~ : Bool,
) -> BytesView? {
  if len > path.length() {
    None
  } else if prefix {
    Some(path[:len])
  } else {
    Some(path[path.length() - len:])
  }
}

///|
fn AffixStrategy::is_match(
  self : AffixStrategy,
  path : Bytes,
  prefix~ : Bool,
) -> Bool {
  for len in self.lens {
    guard AffixStrategy::affix_of(path, len, prefix~) is Some(affix) else {
      break
    }
    if self.map.contains(affix.to_owned()) {
      return true
    }
  }
  false
}

///|
fn AffixStrategy::matches_all(
  self : AffixStrategy,
  path : Bytes,
  prefix~ : Bool,
) -> Bool {
  let mut count = 0
  // If all the affixes match, we should get exactly one match for each
  // literal.
  for len in self.lens {
    guard AffixStrategy::affix_of(path, len, prefix~) is Some(affix) else {
      break
    }
    if self.map.get(affix.to_owned()) is Some(hits) {
      count += hits.length()
    }
  }
  count == self.count
}

///|
fn AffixStrategy::matches_into(
  self : AffixStrategy,
  path : Bytes,
  matches : Array[Int32],
  prefix~ : Bool,
) -> Unit {
  for len in self.lens {
    guard AffixStrategy::affix_of(path, len, prefix~) is Some(affix) else {
      break
    }
    if self.map.get(affix.to_owned()) is Some(hits) {
      matches.append(hits)
    }
  }
}

///|
fn required_ext_is_match(
  m : Map[Bytes, Array[(Int32, @regex.Regex)]],
  candidate : Candidate,
) -> Bool {
  if candidate.ext.is_empty() {
    return false
  }
  match m.get(candidate.ext) {
    None => false
    Some(regexes) => {
      for entry in regexes {
        if regex_is_match(entry.1, candidate.path_arr) {
          return true
        }
      }
      false
    }
  }
}

///|
fn required_ext_matches_all(
  m : Map[Bytes, Array[(Int32, @regex.Regex)]],
  candidate : Candidate,
) -> Bool {
  if candidate.ext.is_empty() {
    return false
  }
  match m.get(candidate.ext) {
    None => false
    Some(regexes) => {
      for entry in regexes {
        if !regex_is_match(entry.1, candidate.path_arr) {
          return false
        }
      }
      true
    }
  }
}

///|
fn required_ext_matches_into(
  m : Map[Bytes, Array[(Int32, @regex.Regex)]],
  candidate : Candidate,
  matches : Array[Int32],
) -> Unit {
  if candidate.ext.is_empty() {
    return
  }
  if m.get(candidate.ext) is Some(regexes) {
    for entry in regexes {
      let (global_index, re) = entry
      if regex_is_match(re, candidate.path_arr) {
        matches.push(global_index)
      }
    }
  }
}

///|
/// The number of regexes grouped together under one combined regex in a
/// `RegexSetStrategy`.
let regex_chunk_size : Int32 = 16

///|
/// A group of regexes along with a combined regex that matches if any of
/// them match.
priv struct RegexChunk {
  /// Combined regex for the whole chunk. `None` if the chunk has only one
  /// regex.
  any : @regex.Regex?
  regexes : Array[@regex.Regex]
  map : Array[Int32]
}

///|
/// Emulates Rust's multi-pattern regex set (`which_overlapping_matches`).
///
/// A single combined regex (an alternation of all patterns) is used to
/// quickly answer `is_match` and to reject non-matching paths. Patterns are
/// further grouped in chunks, each with its own combined regex, so that
/// determining *which* patterns match costs roughly
/// `n / chunk_size + chunk_size * matching_chunks` searches instead of `n`.
priv struct RegexSetStrategy {
  /// Combined regex for the whole set. `None` if there is only one chunk.
  any : @regex.Regex?
  chunks : Array[RegexChunk]
}

///|
fn RegexChunk::is_match(self : RegexChunk, candidate : Candidate) -> Bool {
  match self.any {
    Some(re) => regex_is_match(re, candidate.path_arr)
    None => regex_is_match(self.regexes[0], candidate.path_arr)
  }
}

///|
fn RegexSetStrategy::is_match(
  self : RegexSetStrategy,
  candidate : Candidate,
) -> Bool {
  match self.any {
    Some(re) => regex_is_match(re, candidate.path_arr)
    None => self.chunks.iter().any(chunk => chunk.is_match(candidate))
  }
}

///|
fn RegexSetStrategy::matches_all(
  self : RegexSetStrategy,
  candidate : Candidate,
) -> Bool {
  for chunk in self.chunks {
    for re in chunk.regexes {
      if !regex_is_match(re, candidate.path_arr) {
        return false
      }
    }
  }
  true
}

///|
fn RegexSetStrategy::matches_into(
  self : RegexSetStrategy,
  candidate : Candidate,
  matches : Array[Int32],
) -> Unit {
  if self.any is Some(re) && !regex_is_match(re, candidate.path_arr) {
    return
  }
  for chunk in self.chunks {
    if chunk.any is Some(re) && !regex_is_match(re, candidate.path_arr) {
      continue
    }
    for i, re in chunk.regexes {
      if regex_is_match(re, candidate.path_arr) {
        matches.push(chunk.map[i])
      }
    }
  }
}

///|
priv struct MultiStrategyBuilder {
  literals : Array[String]
  map : Array[Int32]
}

///|
fn MultiStrategyBuilder::new() -> MultiStrategyBuilder {
  { literals: [], map: [], }
}

///|
fn MultiStrategyBuilder::add(
  self : MultiStrategyBuilder,
  global_index : Int32,
  literal : String,
) -> Unit {
  self.map.push(global_index)
  self.literals.push(literal)
}

///|
fn MultiStrategyBuilder::is_empty(self : MultiStrategyBuilder) -> Bool {
  self.literals.is_empty()
}

///|
/// Builds a prefix or suffix strategy from the literals added so far.
fn MultiStrategyBuilder::affix(self : MultiStrategyBuilder) -> AffixStrategy {
  let map : Map[Bytes, Array[Int32]] = Map([])
  let lens : Array[Int32] = []
  for i, lit in self.literals {
    let key = @utf8.encode(lit)
    match map.get(key) {
      Some(hits) => hits.push(self.map[i])
      None => {
        map[key] = [self.map[i]]
        lens.push(key.length())
      }
    }
  }
  lens.sort()
  lens.dedup()
  { map, lens, count: self.literals.length(), }
}

///|
/// Builds a regex set strategy from the regexes added so far.
fn MultiStrategyBuilder::regex_set(
  self : MultiStrategyBuilder,
) -> RegexSetStrategy raise GlobError {
  let chunks = []
  let n = self.literals.length()
  for start = 0; start < n; start = start + regex_chunk_size {
    let end = @cmp.minimum(start + regex_chunk_size, n)
    let regexes = []
    for i in start..<end {
      regexes.push(new_regex(self.literals[i]))
    }
    let any = if end - start > 1 {
      Some(new_regex_any(self.literals[start:end]))
    } else {
      None
    }
    chunks.push({ any, regexes, map: self.map[start:end].to_owned(), })
  }
  let any = if chunks.length() > 1 {
    Some(new_regex_any(self.literals))
  } else {
    None
  }
  { any, chunks, }
}

///|
/// Escape meta-characters within the given glob pattern.
///
/// The escaping works by surrounding meta-characters with brackets. For
/// example, `*` becomes `[*]`.
///
/// # Example
///
/// ```mbt check
/// test {
///   inspect(@globset.escape("foo*bar"), content="foo[*]bar")
///   inspect(@globset.escape("foo?bar"), content="foo[?]bar")
///   inspect(@globset.escape("foo[bar"), content="foo[[]bar")
///   inspect(@globset.escape("foo]bar"), content="foo[]]bar")
///   inspect(@globset.escape("foo{bar"), content="foo[{]bar")
///   inspect(@globset.escape("foo}bar"), content="foo[}]bar")
/// }
/// ```
pub fn escape(s : String) -> String {
  let escaped = StringBuilder()
  for c in s {
    match c {
      // note that ! does not need escaping because it is only special
      // inside brackets
      '?' | '*' | '[' | ']' | '{' | '}' => {
        escaped.write_char('[')
        escaped.write_char(c)
        escaped.write_char(']')
      }
      c => escaped.write_char(c)
    }
  }
  escaped.to_string()
}
