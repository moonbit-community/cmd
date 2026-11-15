///|
/// A literal sequence tagged with whether it is a prefix of the regex.
priv struct LiteralSequence {
  seq : Seq
  mut prefix : Bool
}

///|
fn LiteralSequence::empty() -> LiteralSequence {
  { seq: Seq::empty(), prefix: true, }
}

///|
fn LiteralSequence::infinite() -> LiteralSequence {
  { seq: Seq::infinite(), prefix: true, }
}

///|
fn LiteralSequence::singleton(lit : Lit) -> LiteralSequence {
  { seq: Seq::singleton(lit), prefix: true, }
}

///|
fn LiteralSequence::copy(self : LiteralSequence) -> LiteralSequence {
  { seq: self.seq.copy(), prefix: self.prefix, }
}

///|
fn LiteralSequence::is_good(self : LiteralSequence) -> Bool {
  if self.has_poisonous_literal() {
    return false
  }
  guard self.seq.min_literal_len() is Some(min) else { return false }
  guard self.seq.len() is Some(len) else { return false }
  if min <= 1 {
    return len <= 3
  }
  min >= 2 && len <= 64
}

///|
fn LiteralSequence::is_really_good(self : LiteralSequence) -> Bool {
  if self.has_poisonous_literal() {
    return false
  }
  guard self.seq.min_literal_len() is Some(min) else { return false }
  guard self.seq.len() is Some(len) else { return false }
  min >= 3 && len <= 8
}

///|
fn LiteralSequence::has_poisonous_literal(self : LiteralSequence) -> Bool {
  match self.seq.literals() {
    None => false
    Some(lits) => lits.iter().any(Lit::is_poisonous)
  }
}

///|
fn LiteralSequence::choose(
  self : LiteralSequence,
  other : LiteralSequence,
) -> LiteralSequence {
  let seq1 = self
  let seq2 = other
  seq1.seq.make_inexact()
  seq2.seq.make_inexact()
  if !seq1.seq.is_finite() {
    return seq2
  } else if !seq2.seq.is_finite() {
    return seq1
  }
  if seq1.has_poisonous_literal() {
    return seq2
  } else if seq2.has_poisonous_literal() {
    return seq1
  }
  guard seq1.seq.min_literal_len() is Some(min1) else { return seq2 }
  guard seq2.seq.min_literal_len() is Some(min2) else { return seq1 }
  if min1 < min2 {
    return seq2
  } else if min2 < min1 {
    return seq1
  }
  let len1 = seq1.seq.len().unwrap()
  let len2 = seq2.seq.len().unwrap()
  if len1 < len2 {
    return seq2
  } else if len2 < len1 {
    return seq1
  }
  seq1
}

///|
/// Extracts "inner" literals: literals that must appear somewhere in every
/// match (not necessarily as a prefix).
priv struct InnerExtractor {
  limit_class : Int32
  limit_repeat : Int32
  limit_literal_len : Int32
  limit_total : Int32
}

///|
fn InnerExtractor::new() -> InnerExtractor {
  {
    limit_class: 10,
    limit_repeat: 10,
    limit_literal_len: 100,
    limit_total: 64,
  }
}

///|
fn InnerExtractor::extract_untagged(self : InnerExtractor, hir : Hir) -> Seq {
  let seq = self.extract(hir)
  seq.seq.optimize_for_prefix_by_preference()
  if !seq.is_good() {
    seq.seq.make_infinite()
  }
  seq.seq
}

///|
fn InnerExtractor::extract(self : InnerExtractor, hir : Hir) -> LiteralSequence {
  match hir.kind {
    Empty | Look(_) => LiteralSequence::singleton(Lit::exact(b""))
    Literal(bytes) => {
      let seq = LiteralSequence::singleton(Lit::exact(bytes))
      self.enforce_literal_len(seq)
      seq
    }
    Class(cls) => self.extract_class(cls)
    Repetition(min~, max~, greedy~, sub) =>
      self.extract_repetition(min, max, greedy, sub)
    Capture(sub, ..) => self.extract(sub)
    Concat(hirs) => self.extract_concat(hirs)
    Alternation(hirs) => self.extract_alternation(hirs)
  }
}

///|
fn InnerExtractor::extract_concat(
  self : InnerExtractor,
  hirs : Array[Hir],
) -> LiteralSequence {
  let mut seq = LiteralSequence::singleton(Lit::exact(b""))
  let mut prev : LiteralSequence? = None
  for hir in hirs {
    if seq.seq.is_inexact() {
      if seq.seq.is_empty() {
        return seq
      }
      if seq.is_really_good() {
        return seq
      }
      prev = Some(
        match prev {
          None => seq
          Some(p) => p.choose(seq)
        },
      )
      seq = LiteralSequence::singleton(Lit::exact(b""))
      seq.prefix = false
    }
    seq = self.cross(seq, self.extract(hir))
  }
  match prev {
    Some(p) => p.choose(seq)
    None => seq
  }
}

///|
fn InnerExtractor::extract_alternation(
  self : InnerExtractor,
  hirs : Array[Hir],
) -> LiteralSequence {
  let mut seq = LiteralSequence::empty()
  for hir in hirs {
    if !seq.seq.is_finite() {
      break
    }
    seq = self.union(seq, self.extract(hir))
  }
  seq
}

///|
fn InnerExtractor::extract_repetition(
  self : InnerExtractor,
  min : Int32,
  max : Int32?,
  greedy : Bool,
  sub : Hir,
) -> LiteralSequence {
  let subseq = self.extract(sub)
  if min == 0 {
    if max != Some(1) {
      subseq.seq.make_inexact()
    }
    let empty = LiteralSequence::singleton(Lit::exact(b""))
    if greedy {
      self.union(subseq, empty)
    } else {
      self.union(empty, subseq)
    }
  } else if max is Some(mx) && min == mx {
    let mut seq = LiteralSequence::singleton(Lit::exact(b""))
    let n = if min < self.limit_repeat { min } else { self.limit_repeat }
    for _ in 0..<n {
      if seq.seq.is_inexact() {
        break
      }
      seq = self.cross(seq, subseq.copy())
    }
    if min > self.limit_repeat {
      seq.seq.make_inexact()
    }
    seq
  } else if max is Some(mx) && min < mx {
    let mut seq = LiteralSequence::singleton(Lit::exact(b""))
    let n = if min < self.limit_repeat { min } else { self.limit_repeat }
    for _ in 0..<n {
      if seq.seq.is_inexact() {
        break
      }
      seq = self.cross(seq, subseq.copy())
    }
    seq.seq.make_inexact()
    seq
  } else {
    subseq.seq.make_inexact()
    subseq
  }
}

///|
fn InnerExtractor::extract_class(
  self : InnerExtractor,
  cls : Class,
) -> LiteralSequence {
  let mut count = 0
  for r in cls.ranges() {
    if count > self.limit_class {
      return LiteralSequence::infinite()
    }
    count += r.1 - r.0 + 1
  }
  if count > self.limit_class {
    return LiteralSequence::infinite()
  }
  let seq = LiteralSequence::empty()
  match cls {
    Unicode(ranges) =>
      for r in ranges {
        for c in r.0..<=r.1 {
          if c >= 0xD800 && c <= 0xDFFF {
            continue
          }
          let buf = Buffer()
          encode_utf8(buf, c)
          seq.seq.push(Lit::exact(buf.to_bytes()))
        }
      }
    Bytes(ranges) =>
      for r in ranges {
        for b in r.0..<=r.1 {
          seq.seq.push(Lit::exact(Bytes::make(1, b.to_byte())))
        }
      }
  }
  self.enforce_literal_len(seq)
  seq
}

///|
fn InnerExtractor::cross(
  self : InnerExtractor,
  seq1 : LiteralSequence,
  seq2 : LiteralSequence,
) -> LiteralSequence {
  if !seq2.prefix {
    return seq1.choose(seq2)
  }
  if seq1.seq.max_cross_len(seq2.seq) is Some(len) && len > self.limit_total {
    seq2.seq.make_infinite()
  }
  seq1.seq.cross_forward(seq2.seq)
  self.enforce_literal_len(seq1)
  seq1
}

///|
fn InnerExtractor::union(
  self : InnerExtractor,
  seq1 : LiteralSequence,
  seq2 : LiteralSequence,
) -> LiteralSequence {
  if seq1.seq.max_union_len(seq2.seq) is Some(len) && len > self.limit_total {
    seq1.seq.keep_first_bytes(4)
    seq2.seq.keep_first_bytes(4)
    seq1.seq.dedup()
    seq2.seq.dedup()
    if seq1.seq.max_union_len(seq2.seq) is Some(len) && len > self.limit_total {
      seq2.seq.make_infinite()
    }
  }
  seq1.seq.union(seq2.seq)
  seq1.prefix = seq1.prefix && seq2.prefix
  seq1
}

///|
fn InnerExtractor::enforce_literal_len(
  self : InnerExtractor,
  seq : LiteralSequence,
) -> Unit {
  seq.seq.keep_first_bytes(self.limit_literal_len)
}

///|
/// Extract bounded literal alternatives that every match must contain.
/// These may occur inside a match; they are not necessarily prefixes.
pub fn Hir::inner_literals(self : Hir) -> Seq {
  InnerExtractor::new().extract_untagged(self)
}
