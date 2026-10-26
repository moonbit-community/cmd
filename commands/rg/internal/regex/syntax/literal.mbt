///|
/// A single literal extracted from an HIR, which may be exact (the literal
/// is a complete match) or inexact (only a prefix of a match).
pub(all) struct Lit {
  bytes : Bytes
  exact : Bool
} derive(Debug, Eq, Compare)

///|
pub fn Lit::exact(bytes : Bytes) -> Lit {
  { bytes, exact: true, }
}

///|
pub fn Lit::inexact(bytes : Bytes) -> Lit {
  { bytes, exact: false, }
}

///|
pub fn Lit::len(self : Lit) -> Int32 {
  self.bytes.length()
}

///|
fn Lit::is_poisonous(self : Lit) -> Bool {
  self.bytes.length() == 0 ||
  (self.bytes.length() == 1 && rank(self.bytes[0].to_int()) >= 250)
}

///|
fn Lit::keep_first(self : Lit, len : Int32) -> Lit {
  if len >= self.len() {
    self
  } else {
    { bytes: self.bytes[0:len].to_owned(), exact: false, }
  }
}

///|
fn Lit::keep_last(self : Lit, len : Int32) -> Lit {
  if len >= self.len() {
    self
  } else {
    { bytes: self.bytes[self.len() - len:].to_owned(), exact: false, }
  }
}

///|
/// A sequence of literals. `None` represents the infinite sequence (i.e.
/// every possible literal).
pub(all) struct Seq {
  mut lits : Array[Lit]?
} derive(Debug, Eq)

///|
pub fn Seq::empty() -> Seq {
  { lits: Some([]), }
}

///|
pub fn Seq::infinite() -> Seq {
  { lits: None, }
}

///|
pub fn Seq::singleton(lit : Lit) -> Seq {
  { lits: Some([lit]), }
}

///|
pub fn Seq::copy(self : Seq) -> Seq {
  { lits: self.lits.map(l => l.copy()), }
}

///|
pub fn Seq::literals(self : Seq) -> Array[Lit]? {
  self.lits
}

///|
pub fn Seq::push(self : Seq, lit : Lit) -> Unit {
  guard self.lits is Some(lits) else { return }
  if lits.last() is Some(m) && m == lit {
    return
  }
  lits.push(lit)
}

///|
pub fn Seq::make_inexact(self : Seq) -> Unit {
  guard self.lits is Some(lits) else { return }
  for i in 0..<lits.length() {
    lits[i] = { ..lits[i], exact: false, }
  }
}

///|
pub fn Seq::make_infinite(self : Seq) -> Unit {
  self.lits = None
}

///|
pub fn Seq::is_finite(self : Seq) -> Bool {
  self.lits is Some(_)
}

///|
pub fn Seq::len(self : Seq) -> Int32? {
  self.lits.map(l => l.length())
}

///|
pub fn Seq::is_empty(self : Seq) -> Bool {
  self.len() == Some(0)
}

///|
pub fn Seq::is_exact(self : Seq) -> Bool {
  match self.lits {
    None => false
    Some(lits) => lits.iter().all(x => x.exact)
  }
}

///|
pub fn Seq::is_inexact(self : Seq) -> Bool {
  match self.lits {
    None => true
    Some(lits) => lits.iter().all(x => !x.exact)
  }
}

///|
pub fn Seq::min_literal_len(self : Seq) -> Int32? {
  guard self.lits is Some(lits) && lits.length() > 0 else { return None }
  let mut m = lits[0].len()
  for l in lits {
    if l.len() < m {
      m = l.len()
    }
  }
  Some(m)
}

///|
pub fn Seq::max_literal_len(self : Seq) -> Int32? {
  guard self.lits is Some(lits) && lits.length() > 0 else { return None }
  let mut m = lits[0].len()
  for l in lits {
    if l.len() > m {
      m = l.len()
    }
  }
  Some(m)
}

///|
pub fn Seq::max_union_len(self : Seq, other : Seq) -> Int32? {
  match (self.len(), other.len()) {
    (Some(a), Some(b)) => Some(a + b)
    _ => None
  }
}

///|
pub fn Seq::max_cross_len(self : Seq, other : Seq) -> Int32? {
  match (self.len(), other.len()) {
    (Some(a), Some(b)) => {
      let r = a.to_int64() * b.to_int64()
      Some(if r > 0x7FFFFFFFL { 0x7FFFFFFF } else { r.to_int() })
    }
    _ => None
  }
}

///|
pub fn Seq::dedup(self : Seq) -> Unit {
  guard self.lits is Some(lits) else { return }
  let out : Array[Lit] = []
  for lit in lits {
    match out.last() {
      Some(prev) if prev.bytes == lit.bytes =>
        if prev.exact != lit.exact {
          out[out.length() - 1] = { ..prev, exact: false, }
        }
      _ => out.push(lit)
    }
  }
  self.lits = Some(out)
}

///|
pub fn Seq::sort(self : Seq) -> Unit {
  guard self.lits is Some(lits) else { return }
  lits.sort_by((a, b) => {
    let c = compare_bytes(a.bytes, b.bytes)
    if c != 0 {
      c
    } else {
      a.exact.compare(b.exact)
    }
  })
}

///|
fn compare_bytes(a : Bytes, b : Bytes) -> Int32 {
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    if a[i] != b[i] {
      return a[i].to_int() - b[i].to_int()
    }
  }
  a.length() - b.length()
}

///|
pub fn Seq::keep_first_bytes(self : Seq, len : Int32) -> Unit {
  guard self.lits is Some(lits) else { return }
  for i in 0..<lits.length() {
    lits[i] = lits[i].keep_first(len)
  }
}

///|
pub fn Seq::keep_last_bytes(self : Seq, len : Int32) -> Unit {
  guard self.lits is Some(lits) else { return }
  for i in 0..<lits.length() {
    lits[i] = lits[i].keep_last(len)
  }
}

///|
fn concat_bytes(a : Bytes, b : Bytes) -> Bytes {
  let buf = Buffer()
  buf.write_bytes(a)
  buf.write_bytes(b)
  buf.to_bytes()
}

///|
/// Returns `None` if the cross product is a no-op.
fn Seq::cross_preamble(self : Seq, other : Seq) -> (Array[Lit], Array[Lit])? {
  match other.lits {
    None => {
      if self.min_literal_len() == Some(0) {
        self.lits = None
      } else {
        self.make_inexact()
      }
      None
    }
    Some(lits2) =>
      match self.lits {
        None => {
          other.lits = Some([])
          None
        }
        Some(lits1) => Some((lits1, lits2))
      }
  }
}

///|
/// Modifies this sequence to be the cross product of it with `other`, in
/// the forward direction. `other` is drained.
pub fn Seq::cross_forward(self : Seq, other : Seq) -> Unit {
  guard self.cross_preamble(other) is Some((lits1, lits2)) else { return }
  let out = []
  for selflit in lits1 {
    if !selflit.exact {
      out.push(selflit)
      continue
    }
    for otherlit in lits2 {
      out.push({
        bytes: concat_bytes(selflit.bytes, otherlit.bytes),
        exact: otherlit.exact,
      })
    }
  }
  other.lits = Some([])
  self.lits = Some(out)
  self.dedup()
}

///|
/// Like `cross_forward`, but prepends `other`'s literals.
pub fn Seq::cross_reverse(self : Seq, other : Seq) -> Unit {
  guard self.cross_preamble(other) is Some((lits1, lits2)) else { return }
  let out = []
  for i, otherlit in lits2 {
    for selflit in lits1 {
      if !selflit.exact {
        if i == 0 {
          out.push(selflit)
        }
        continue
      }
      out.push({
        bytes: concat_bytes(otherlit.bytes, selflit.bytes),
        exact: otherlit.exact,
      })
    }
  }
  other.lits = Some([])
  self.lits = Some(out)
  self.dedup()
}

///|
/// Unions `other` into this sequence. `other` is drained.
pub fn Seq::union(self : Seq, other : Seq) -> Unit {
  match other.lits {
    None => self.make_infinite()
    Some(lits2) => {
      other.lits = Some([])
      guard self.lits is Some(lits1) else { return }
      lits1.append(lits2)
      self.dedup()
    }
  }
}

///|
pub fn Seq::longest_common_prefix(self : Seq) -> Bytes? {
  guard self.lits is Some(lits) && lits.length() > 0 else { return None }
  let base = lits[0].bytes
  let mut len = base.length()
  for i in 1..<lits.length() {
    let m = lits[i].bytes
    let mut n = 0
    while n < len && n < m.length() && m[n] == base[n] {
      n += 1
    }
    len = n
    if len == 0 {
      return Some(b"")
    }
  }
  Some(base[0:len].to_owned())
}

///|
pub fn Seq::longest_common_suffix(self : Seq) -> Bytes? {
  guard self.lits is Some(lits) && lits.length() > 0 else { return None }
  let base = lits[0].bytes
  let mut len = base.length()
  for i in 1..<lits.length() {
    let m = lits[i].bytes
    let mut n = 0
    while n < len &&
          n < m.length() &&
          m[m.length() - 1 - n] == base[base.length() - 1 - n] {
      n += 1
    }
    len = n
    if len == 0 {
      return Some(b"")
    }
  }
  Some(base[base.length() - len:].to_owned())
}

///|
/// Removes literals that are made redundant by an earlier literal that is
/// a prefix of them (in preference order).
fn preference_minimize(lits : Array[Lit], keep_exact : Bool) -> Array[Lit] {
  // A simple trie keyed by bytes; matches[state] is the 1-based index of the
  // literal that ends there.
  let trans : Array[Map[Int32, Int32]] = [{}]
  let matches : Array[Int32] = [0]
  let out : Array[Lit] = []
  let make_inexact = []
  let mut next_index = 1
  for lit in lits {
    let mut prev = 0
    let mut dup = matches[0]
    if dup == 0 {
      for b in lit.bytes {
        let key = b.to_int()
        match trans[prev].get(key) {
          Some(next) => {
            prev = next
            if matches[prev] != 0 {
              dup = matches[prev]
              break
            }
          }
          None => {
            let next = trans.length()
            trans.push({})
            matches.push(0)
            trans[prev][key] = next
            prev = next
          }
        }
      }
    }
    if dup != 0 {
      if !keep_exact {
        make_inexact.push(dup - 1)
      }
      continue
    }
    matches[prev] = next_index
    next_index += 1
    out.push(lit)
  }
  for i in make_inexact {
    out[i] = { ..out[i], exact: false, }
  }
  out
}

///|
pub fn Seq::minimize_by_preference(self : Seq) -> Unit {
  if self.lits is Some(lits) {
    self.lits = Some(preference_minimize(lits, false))
  }
}

///|
pub fn Seq::optimize_for_prefix_by_preference(self : Seq) -> Unit {
  self.optimize_by_preference(true)
}

///|
pub fn Seq::optimize_for_suffix_by_preference(self : Seq) -> Unit {
  self.optimize_by_preference(false)
}

///|
fn Seq::optimize_by_preference(self : Seq, prefix : Bool) -> Unit {
  guard self.len() is Some(origlen) else { return }
  if self.min_literal_len() == Some(0) {
    self.make_infinite()
    return
  }
  if prefix && self.lits is Some(lits) {
    self.lits = Some(preference_minimize(lits, true))
  }
  let fix = if prefix {
    self.longest_common_prefix()
  } else {
    self.longest_common_suffix()
  }
  if fix is Some(fix) {
    if prefix &&
      origlen > 1 &&
      fix.length() >= 1 &&
      fix.length() <= 3 &&
      rank(fix[0].to_int()) < 200 {
      self.keep_first_bytes(1)
      self.dedup()
      return
    }
    let isfast = self.is_exact() &&
      (match self.len() {
        Some(len) => len <= 16
        None => false
      })
    let usefix = fix.length() > 4 || (fix.length() > 1 && !isfast)
    if usefix {
      if prefix {
        self.keep_first_bytes(fix.length())
      } else {
        self.keep_last_bytes(fix.length())
      }
      self.dedup()
    }
  }
  let exact = if self.is_exact() { Some(self.copy()) } else { None }
  let attempts = [(5, 10), (4, 10), (3, 64), (2, 64), (1, 10)]
  for attempt in attempts {
    let (keep, limit) = attempt
    guard self.len() is Some(len) else { break }
    if len <= limit {
      break
    }
    if prefix {
      self.keep_first_bytes(keep)
    } else {
      self.keep_last_bytes(keep)
    }
    if prefix && self.lits is Some(lits) {
      self.lits = Some(preference_minimize(lits, true))
    }
  }
  if self.lits is Some(lits) && lits.iter().any(l => l.is_poisonous()) {
    self.make_infinite()
  }
  if exact is Some(exact) {
    if !self.is_finite() {
      self.lits = exact.lits
      return
    }
    if self.min_literal_len() is Some(len) && len <= 2 {
      self.lits = exact.lits
      return
    }
    if self.len() is Some(len) && len > 64 {
      self.lits = exact.lits
      return
    }
  }
}

///|
/// Which end of a regex to extract literals from.
pub(all) enum ExtractKind {
  Prefix
  Suffix
}

///|
/// Extracts literal sequences from an HIR.
pub(all) struct Extractor {
  kind : ExtractKind
  limit_class : Int32
  limit_repeat : Int32
  limit_literal_len : Int32
  limit_total : Int32
}

///|
pub fn Extractor::new() -> Extractor {
  {
    kind: Prefix,
    limit_class: 10,
    limit_repeat: 10,
    limit_literal_len: 100,
    limit_total: 250,
  }
}

///|
pub fn Extractor::extract(self : Extractor, hir : Hir) -> Seq {
  match hir.kind {
    Empty | Look(_) => Seq::singleton(Lit::exact(b""))
    Literal(bytes) => {
      let seq = Seq::singleton(Lit::exact(bytes))
      self.enforce_literal_len(seq)
      seq
    }
    Class(cls) => self.extract_class(cls)
    Repetition(min~, max~, greedy~, sub) =>
      self.extract_repetition(min, max, greedy, sub)
    Capture(sub, ..) => self.extract(sub)
    Concat(hirs) =>
      match self.kind {
        Prefix => self.extract_concat(hirs)
        Suffix => self.extract_concat(hirs.rev())
      }
    Alternation(hirs) => self.extract_alternation(hirs)
  }
}

///|
fn Extractor::extract_concat(self : Extractor, hirs : Array[Hir]) -> Seq {
  let mut seq = Seq::singleton(Lit::exact(b""))
  for hir in hirs {
    if seq.is_inexact() {
      break
    }
    seq = self.cross(seq, self.extract(hir))
  }
  seq
}

///|
fn Extractor::extract_alternation(self : Extractor, hirs : Array[Hir]) -> Seq {
  let mut seq = Seq::empty()
  for hir in hirs {
    if !seq.is_finite() {
      break
    }
    seq = self.union(seq, self.extract(hir))
  }
  seq
}

///|
fn Extractor::extract_repetition(
  self : Extractor,
  min : Int32,
  max : Int32?,
  greedy : Bool,
  sub : Hir,
) -> Seq {
  let subseq = self.extract(sub)
  if min == 0 {
    if max != Some(1) {
      subseq.make_inexact()
    }
    let empty = Seq::singleton(Lit::exact(b""))
    if greedy {
      self.union(subseq, empty)
    } else {
      self.union(empty, subseq)
    }
  } else if max == Some(min) {
    let mut seq = Seq::singleton(Lit::exact(b""))
    let n = if min < self.limit_repeat { min } else { self.limit_repeat }
    for _ in 0..<n {
      if seq.is_inexact() {
        break
      }
      seq = self.cross(seq, subseq.copy())
    }
    if min > self.limit_repeat {
      seq.make_inexact()
    }
    seq
  } else {
    let mut seq = Seq::singleton(Lit::exact(b""))
    let n = if min < self.limit_repeat { min } else { self.limit_repeat }
    for _ in 0..<n {
      if seq.is_inexact() {
        break
      }
      seq = self.cross(seq, subseq.copy())
    }
    seq.make_inexact()
    seq
  }
}

///|
fn Extractor::class_over_limit(self : Extractor, cls : Class) -> Bool {
  let mut count = 0
  for r in cls.ranges() {
    if count > self.limit_class {
      return true
    }
    count += r.1 - r.0 + 1
  }
  count > self.limit_class
}

///|
fn Extractor::extract_class(self : Extractor, cls : Class) -> Seq {
  if self.class_over_limit(cls) {
    return Seq::infinite()
  }
  let seq = Seq::empty()
  match cls {
    Unicode(ranges) =>
      for r in ranges {
        for c in r.0..<=r.1 {
          if c >= 0xD800 && c <= 0xDFFF {
            continue
          }
          let buf = Buffer()
          encode_utf8(buf, c)
          seq.push(Lit::exact(buf.to_bytes()))
        }
      }
    Bytes(ranges) =>
      for r in ranges {
        for b in r.0..<=r.1 {
          seq.push(Lit::exact(Bytes::make(1, b.to_byte())))
        }
      }
  }
  self.enforce_literal_len(seq)
  seq
}

///|
fn Extractor::cross(self : Extractor, seq1 : Seq, seq2 : Seq) -> Seq {
  if seq1.max_cross_len(seq2) is Some(len) && len > self.limit_total {
    seq2.make_infinite()
  }
  match self.kind {
    Suffix => seq1.cross_reverse(seq2)
    Prefix => seq1.cross_forward(seq2)
  }
  self.enforce_literal_len(seq1)
  seq1
}

///|
fn Extractor::union(self : Extractor, seq1 : Seq, seq2 : Seq) -> Seq {
  if seq1.max_union_len(seq2) is Some(len) && len > self.limit_total {
    match self.kind {
      Prefix => {
        seq1.keep_first_bytes(4)
        seq2.keep_first_bytes(4)
      }
      Suffix => {
        seq1.keep_last_bytes(4)
        seq2.keep_last_bytes(4)
      }
    }
    seq1.dedup()
    seq2.dedup()
    if seq1.max_union_len(seq2) is Some(len) && len > self.limit_total {
      seq2.make_infinite()
    }
  }
  seq1.union(seq2)
  seq1
}

///|
fn Extractor::enforce_literal_len(self : Extractor, seq : Seq) -> Unit {
  match self.kind {
    Prefix => seq.keep_first_bytes(self.limit_literal_len)
    Suffix => seq.keep_last_bytes(self.limit_literal_len)
  }
}
