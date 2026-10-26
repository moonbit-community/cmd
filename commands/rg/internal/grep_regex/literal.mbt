///|
/// A literal sequence tagged with whether it is a prefix of the regex.
priv struct TSeq {
  seq : @syntax.Seq
  mut prefix : Bool
}

///|
fn TSeq::empty() -> TSeq {
  { seq: @syntax.Seq::empty(), prefix: true, }
}

///|
fn TSeq::infinite() -> TSeq {
  { seq: @syntax.Seq::infinite(), prefix: true, }
}

///|
fn TSeq::singleton(lit : @syntax.Lit) -> TSeq {
  { seq: @syntax.Seq::singleton(lit), prefix: true, }
}

///|
fn TSeq::copy(self : TSeq) -> TSeq {
  { seq: self.seq.copy(), prefix: self.prefix, }
}

///|
fn TSeq::is_good(self : TSeq) -> Bool {
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
fn TSeq::is_really_good(self : TSeq) -> Bool {
  if self.has_poisonous_literal() {
    return false
  }
  guard self.seq.min_literal_len() is Some(min) else { return false }
  guard self.seq.len() is Some(len) else { return false }
  min >= 3 && len <= 8
}

///|
fn is_poisonous(lit : @syntax.Lit) -> Bool {
  lit.bytes.length() == 0 ||
  (lit.bytes.length() == 1 && @syntax.rank(lit.bytes[0].to_int()) >= 250)
}

///|
fn TSeq::has_poisonous_literal(self : TSeq) -> Bool {
  match self.seq.literals() {
    None => false
    Some(lits) => lits.iter().any(is_poisonous)
  }
}

///|
fn TSeq::choose(self : TSeq, other : TSeq) -> TSeq {
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
fn InnerExtractor::extract_untagged(
  self : InnerExtractor,
  hir : @syntax.Hir,
) -> @syntax.Seq {
  let seq = self.extract(hir)
  seq.seq.optimize_for_prefix_by_preference()
  if !seq.is_good() {
    seq.seq.make_infinite()
  }
  seq.seq
}

///|
fn InnerExtractor::extract(self : InnerExtractor, hir : @syntax.Hir) -> TSeq {
  match hir.kind {
    Empty | Look(_) => TSeq::singleton(@syntax.Lit::exact(b""))
    Literal(bytes) => {
      let seq = TSeq::singleton(@syntax.Lit::exact(bytes))
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
  hirs : Array[@syntax.Hir],
) -> TSeq {
  let mut seq = TSeq::singleton(@syntax.Lit::exact(b""))
  let mut prev : TSeq? = None
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
      seq = TSeq::singleton(@syntax.Lit::exact(b""))
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
  hirs : Array[@syntax.Hir],
) -> TSeq {
  let mut seq = TSeq::empty()
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
  sub : @syntax.Hir,
) -> TSeq {
  let subseq = self.extract(sub)
  if min == 0 {
    if max != Some(1) {
      subseq.seq.make_inexact()
    }
    let empty = TSeq::singleton(@syntax.Lit::exact(b""))
    if greedy {
      self.union(subseq, empty)
    } else {
      self.union(empty, subseq)
    }
  } else if max is Some(mx) && min == mx {
    let mut seq = TSeq::singleton(@syntax.Lit::exact(b""))
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
    let mut seq = TSeq::singleton(@syntax.Lit::exact(b""))
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
  cls : @syntax.Class,
) -> TSeq {
  let mut count = 0
  for r in cls.ranges() {
    if count > self.limit_class {
      return TSeq::infinite()
    }
    count += r.1 - r.0 + 1
  }
  if count > self.limit_class {
    return TSeq::infinite()
  }
  let seq = TSeq::empty()
  match cls {
    Unicode(ranges) =>
      for r in ranges {
        for c in r.0..<=r.1 {
          if c >= 0xD800 && c <= 0xDFFF {
            continue
          }
          let buf = Buffer()
          @syntax.encode_utf8(buf, c)
          seq.seq.push(@syntax.Lit::exact(buf.to_bytes()))
        }
      }
    Bytes(ranges) =>
      for r in ranges {
        for b in r.0..<=r.1 {
          seq.seq.push(@syntax.Lit::exact(Bytes::make(1, b.to_byte())))
        }
      }
  }
  self.enforce_literal_len(seq)
  seq
}

///|
fn InnerExtractor::cross(
  self : InnerExtractor,
  seq1 : TSeq,
  seq2 : TSeq,
) -> TSeq {
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
  seq1 : TSeq,
  seq2 : TSeq,
) -> TSeq {
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
  seq : TSeq,
) -> Unit {
  seq.seq.keep_first_bytes(self.limit_literal_len)
}

///|
/// Builds the "fast line regex" from inner literals, if worthwhile.
fn inner_literals_regex(
  chir : ConfiguredHIR,
  re : @regex.Regex,
) -> @regex.Regex? raise GrepRegexError {
  if chir.config.line_terminator is None {
    return None
  }
  if re.is_accelerated() && !chir.hir.props.look_set.contains_word_unicode() {
    return None
  }
  if chir.hir.props.alternation_literal {
    return None
  }
  let seq = InnerExtractor::new().extract_untagged(chir.hir)
  guard seq.literals() is Some(lits) && lits.length() > 0 else { return None }
  let hir = @syntax.Hir::alternation(
    lits.map(l => @syntax.Hir::literal(l.bytes)),
  )
  Some(
    @regex.Regex::from_hir(hir) catch {
      e => raise GrepRegexError(Regex(e.to_string()))
    },
  )
}
