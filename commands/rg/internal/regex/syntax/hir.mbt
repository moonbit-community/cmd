///|
/// Properties computed for every HIR node.
pub(all) struct Props {
  minimum_len : Int32?
  maximum_len : Int32?
  look_set : LookSet
  look_set_prefix : LookSet
  look_set_suffix : LookSet
  look_set_prefix_any : LookSet
  look_set_suffix_any : LookSet
  utf8 : Bool
  explicit_captures_len : Int32
  static_explicit_captures_len : Int32?
  literal : Bool
  alternation_literal : Bool
} derive(Debug, Eq)

///|
/// The high-level intermediate representation of a regular expression.
pub(all) struct Hir {
  kind : HirKind
  props : Props
} derive(Debug, Eq)

///|
pub(all) enum HirKind {
  Empty
  Literal(Bytes)
  Class(Class)
  Look(Look)
  Repetition(min~ : Int32, max~ : Int32?, greedy~ : Bool, Hir)
  Capture(index~ : Int32, name~ : String?, Hir)
  Concat(Array[Hir])
  Alternation(Array[Hir])
} derive(Debug, Eq)

///|
let empty_props : Props = {
  minimum_len: Some(0),
  maximum_len: Some(0),
  look_set: LookSet::empty(),
  look_set_prefix: LookSet::empty(),
  look_set_suffix: LookSet::empty(),
  look_set_prefix_any: LookSet::empty(),
  look_set_suffix_any: LookSet::empty(),
  utf8: true,
  explicit_captures_len: 0,
  static_explicit_captures_len: Some(0),
  literal: false,
  alternation_literal: false,
}

///|
pub fn Hir::empty() -> Hir {
  { kind: Empty, props: empty_props, }
}

///|
/// An expression that never matches.
pub fn Hir::fail() -> Hir {
  let class = Class::Bytes([])
  { kind: Class(class), props: class_props(class), }
}

///|
fn is_valid_utf8(b : BytesView) -> Bool {
  let mut i = 0
  let n = b.length()
  while i < n {
    let c = b[i].to_int()
    if c < 0x80 {
      i += 1
      continue
    }
    let (len, min) = if c >= 0xC2 && c <= 0xDF {
      (2, 0x80)
    } else if c >= 0xE0 && c <= 0xEF {
      (3, 0x800)
    } else if c >= 0xF0 && c <= 0xF4 {
      (4, 0x10000)
    } else {
      return false
    }
    if i + len > n {
      return false
    }
    let mut cp = c & (0x7F >> len)
    for j in 1..<len {
      let cc = b[i + j].to_int()
      if (cc & 0xC0) != 0x80 {
        return false
      }
      cp = (cp << 6) | (cc & 0x3F)
    }
    if cp < min || cp > 0x10FFFF || (cp >= 0xD800 && cp <= 0xDFFF) {
      return false
    }
    i += len
  }
  true
}

///|
pub fn Hir::literal(bytes : Bytes) -> Hir {
  if bytes.length() == 0 {
    return Hir::empty()
  }
  {
    kind: Literal(bytes),
    props: {
      ..empty_props,
      minimum_len: Some(bytes.length()),
      maximum_len: Some(bytes.length()),
      utf8: is_valid_utf8(bytes),
      literal: true,
      alternation_literal: true,
    },
  }
}

///|
fn class_props(class : Class) -> Props {
  {
    ..empty_props,
    minimum_len: class.minimum_len(),
    maximum_len: class.maximum_len(),
    utf8: match class {
      Unicode(_) => true
      Bytes(_) => class.is_ascii()
    },
  }
}

///|
pub fn Hir::class(class : Class) -> Hir {
  if class.is_empty() {
    return Hir::fail()
  } else if class.literal() is Some(bytes) {
    return Hir::literal(bytes)
  }
  { kind: Class(class), props: class_props(class), }
}

///|
pub fn Hir::look(look : Look) -> Hir {
  let set = LookSet::singleton(look)
  {
    kind: Look(look),
    props: {
      ..empty_props,
      look_set: set,
      look_set_prefix: set,
      look_set_suffix: set,
      look_set_prefix_any: set,
      look_set_suffix_any: set,
    },
  }
}

///|
pub fn Hir::repetition(
  min : Int32,
  max : Int32?,
  greedy : Bool,
  sub : Hir,
) -> Hir {
  let mut min = min
  let mut max = max
  if sub.props.maximum_len == Some(0) {
    min = if min < 1 { min } else { 1 }
    max = match max {
      Some(n) => Some(if n < 1 { n } else { 1 })
      None => Some(1)
    }
  }
  if min == 0 && max == Some(0) {
    return Hir::empty()
  } else if min == 1 && max == Some(1) {
    return sub
  }
  let p = sub.props
  let minimum_len = match p.minimum_len {
    Some(m) => {
      let r = m.to_int64() * min.to_int64()
      Some(if r > 0x7FFFFFFFL { 0x7FFFFFFF } else { r.to_int() })
    }
    None => None
  }
  let maximum_len = match (max, p.maximum_len) {
    (Some(rm), Some(cm)) => {
      let r = rm.to_int64() * cm.to_int64()
      if r > 0x7FFFFFFFL {
        None
      } else {
        Some(r.to_int())
      }
    }
    _ => None
  }
  let mut static_len = p.static_explicit_captures_len
  if min == 0 && static_len is Some(len) && len > 0 {
    static_len = if max == Some(0) { Some(0) } else { None }
  }
  let props : Props = {
    minimum_len,
    maximum_len,
    look_set: p.look_set,
    look_set_prefix: if min > 0 {
      p.look_set_prefix
    } else {
      LookSet::empty()
    },
    look_set_suffix: if min > 0 {
      p.look_set_suffix
    } else {
      LookSet::empty()
    },
    look_set_prefix_any: p.look_set_prefix_any,
    look_set_suffix_any: p.look_set_suffix_any,
    utf8: p.utf8,
    explicit_captures_len: p.explicit_captures_len,
    static_explicit_captures_len: static_len,
    literal: false,
    alternation_literal: false,
  }
  { kind: Repetition(min~, max~, greedy~, sub), props, }
}

///|
pub fn Hir::capture(index : Int32, name : String?, sub : Hir) -> Hir {
  let p = sub.props
  {
    kind: Capture(index~, name~, sub),
    props: {
      ..p,
      explicit_captures_len: p.explicit_captures_len + 1,
      static_explicit_captures_len: p.static_explicit_captures_len.map(x => {
        x + 1
      }),
      literal: false,
      alternation_literal: false,
    },
  }
}

///|
pub fn Hir::concat(subs : Array[Hir]) -> Hir {
  let new : Array[Hir] = []
  let mut prior : Buffer? = None
  fn flush() {
    if prior is Some(buf) {
      new.push(Hir::literal(buf.to_bytes()))
      prior = None
    }
  }

  fn add(h : Hir) {
    match h.kind {
      Literal(bytes) =>
        match prior {
          Some(buf) => buf.write_bytes(bytes)
          None => {
            let buf = Buffer()
            buf.write_bytes(bytes)
            prior = Some(buf)
          }
        }
      Empty => ()
      _ => {
        flush()
        new.push(h)
      }
    }
  }

  for sub in subs {
    match sub.kind {
      Concat(subs2) =>
        for s in subs2 {
          add(s)
        }
      _ => add(sub)
    }
  }
  flush()
  if new.is_empty() {
    return Hir::empty()
  } else if new.length() == 1 {
    return new[0]
  }
  { kind: Concat(new), props: concat_props(new), }
}

///|
fn concat_props(xs : Array[Hir]) -> Props {
  let mut minimum_len : Int32? = Some(0)
  let mut maximum_len : Int32? = Some(0)
  let mut look_set = LookSet::empty()
  let mut utf8 = true
  let mut explicit = 0
  let mut static_len : Int32? = Some(0)
  let mut literal = true
  let mut alternation_literal = true
  for x in xs {
    let p = x.props
    look_set = look_set.union(p.look_set)
    utf8 = utf8 && p.utf8
    explicit += p.explicit_captures_len
    static_len = match (p.static_explicit_captures_len, static_len) {
      (Some(a), Some(b)) => Some(a + b)
      _ => None
    }
    literal = literal && p.literal
    alternation_literal = alternation_literal && p.alternation_literal
    if minimum_len is Some(m) {
      minimum_len = match p.minimum_len {
        None => None
        Some(len) => Some(m + len)
      }
    }
    if maximum_len is Some(m) {
      maximum_len = match p.maximum_len {
        None => None
        Some(len) => Some(m + len)
      }
    }
  }
  let mut prefix = LookSet::empty()
  let mut prefix_any = LookSet::empty()
  for x in xs {
    prefix = prefix.union(x.props.look_set_prefix)
    prefix_any = prefix_any.union(x.props.look_set_prefix_any)
    if x.props.maximum_len is Some(0) {
      continue
    }
    break
  }
  let mut suffix = LookSet::empty()
  let mut suffix_any = LookSet::empty()
  for i = xs.length() - 1; i >= 0; i = i - 1 {
    let x = xs[i]
    suffix = suffix.union(x.props.look_set_suffix)
    suffix_any = suffix_any.union(x.props.look_set_suffix_any)
    if x.props.maximum_len is Some(0) {
      continue
    }
    break
  }
  {
    minimum_len,
    maximum_len,
    look_set,
    look_set_prefix: prefix,
    look_set_suffix: suffix,
    look_set_prefix_any: prefix_any,
    look_set_suffix_any: suffix_any,
    utf8,
    explicit_captures_len: explicit,
    static_explicit_captures_len: static_len,
    literal,
    alternation_literal,
  }
}

///|
fn union_props(xs : Array[Hir]) -> Props {
  let fix = if xs.is_empty() { LookSet::empty() } else { LookSet::full() }
  let mut minimum_len : Int32? = None
  let mut maximum_len : Int32? = None
  let mut look_set = LookSet::empty()
  let mut prefix = fix
  let mut suffix = fix
  let mut prefix_any = LookSet::empty()
  let mut suffix_any = LookSet::empty()
  let mut utf8 = true
  let mut explicit = 0
  let mut static_len : Int32? = if xs.is_empty() {
    None
  } else {
    xs[0].props.static_explicit_captures_len
  }
  let mut alternation_literal = true
  let mut min_poisoned = false
  let mut max_poisoned = false
  for x in xs {
    let p = x.props
    look_set = look_set.union(p.look_set)
    prefix = prefix.intersect(p.look_set_prefix)
    suffix = suffix.intersect(p.look_set_suffix)
    prefix_any = prefix_any.union(p.look_set_prefix_any)
    suffix_any = suffix_any.union(p.look_set_suffix_any)
    utf8 = utf8 && p.utf8
    explicit += p.explicit_captures_len
    if static_len != p.static_explicit_captures_len {
      static_len = None
    }
    alternation_literal = alternation_literal && p.literal
    if !min_poisoned {
      match p.minimum_len {
        Some(xmin) =>
          match minimum_len {
            None => minimum_len = Some(xmin)
            Some(pm) => if xmin < pm { minimum_len = Some(xmin) }
          }
        None => {
          minimum_len = None
          min_poisoned = true
        }
      }
    }
    if !max_poisoned {
      match p.maximum_len {
        Some(xmax) =>
          match maximum_len {
            None => maximum_len = Some(xmax)
            Some(pm) => if xmax > pm { maximum_len = Some(xmax) }
          }
        None => {
          maximum_len = None
          max_poisoned = true
        }
      }
    }
  }
  {
    minimum_len,
    maximum_len,
    look_set,
    look_set_prefix: prefix,
    look_set_suffix: suffix,
    look_set_prefix_any: prefix_any,
    look_set_suffix_any: suffix_any,
    utf8,
    explicit_captures_len: explicit,
    static_explicit_captures_len: static_len,
    literal: false,
    alternation_literal,
  }
}

///|
/// Decodes a single UTF-8 encoded scalar value occupying the whole slice.
fn decode_single_char(b : Bytes) -> Int32? {
  if !is_valid_utf8(b) {
    return None
  }
  let c = b[0].to_int()
  let (len, init) = if c < 0x80 {
    (1, c)
  } else if c < 0xE0 {
    (2, c & 0x1F)
  } else if c < 0xF0 {
    (3, c & 0x0F)
  } else {
    (4, c & 0x07)
  }
  if len != b.length() {
    return None
  }
  let mut cp = init
  for j in 1..<len {
    cp = (cp << 6) | (b[j].to_int() & 0x3F)
  }
  Some(cp)
}

///|
pub fn Hir::alternation(subs : Array[Hir]) -> Hir {
  let new : Array[Hir] = []
  for sub in subs {
    match sub.kind {
      Alternation(subs2) => new.append(subs2)
      _ => new.push(sub)
    }
  }
  if new.is_empty() {
    return Hir::fail()
  } else if new.length() == 1 {
    return new[0]
  }
  // Singleton chars.
  let chars = []
  let mut all_chars = true
  for h in new {
    match h.kind {
      Literal(b) =>
        match decode_single_char(b) {
          Some(c) => chars.push((c, c))
          None => {
            all_chars = false
            break
          }
        }
      _ => {
        all_chars = false
        break
      }
    }
  }
  if all_chars {
    return Hir::class(Class::new_unicode(chars))
  }
  let bytes = []
  let mut all_bytes = true
  for h in new {
    match h.kind {
      Literal(b) if b.length() == 1 =>
        bytes.push((b[0].to_int(), b[0].to_int()))
      _ => {
        all_bytes = false
        break
      }
    }
  }
  if all_bytes {
    return Hir::class(Class::new_bytes(bytes))
  }
  // All classes, as Unicode.
  let mut ucls : Class? = Some(Class::Unicode([]))
  for h in new {
    match (h.kind, ucls) {
      (Class(c), Some(acc)) =>
        match c.to_unicode() {
          Some(u) => ucls = Some(acc.union(u))
          None => ucls = None
        }
      _ => ucls = None
    }
  }
  if ucls is Some(c) {
    return Hir::class(c)
  }
  let mut bcls : Class? = Some(Class::Bytes([]))
  for h in new {
    match (h.kind, bcls) {
      (Class(c), Some(acc)) =>
        match c.to_bytes() {
          Some(b) => bcls = Some(acc.union(b))
          None => bcls = None
        }
      _ => bcls = None
    }
  }
  if bcls is Some(c) {
    return Hir::class(c)
  }
  match lift_common_prefix(new) {
    Some(h) => h
    None => { kind: Alternation(new), props: union_props(new), }
  }
}

///|
fn lift_common_prefix(hirs : Array[Hir]) -> Hir? {
  if hirs.length() <= 1 {
    return None
  }
  guard hirs[0].kind is Concat(first) else { return None }
  if first.is_empty() {
    return None
  }
  let mut len = first.length()
  for i in 1..<hirs.length() {
    guard hirs[i].kind is Concat(xs) else { return None }
    let mut common = 0
    while common < len && common < xs.length() && first[common] == xs[common] {
      common += 1
    }
    len = common
    if len == 0 {
      return None
    }
  }
  let prefix = first[0:len].to_owned()
  let suffix_alts = []
  for h in hirs {
    guard h.kind is Concat(xs) else { abort("unreachable") }
    suffix_alts.push(Hir::concat(xs[len:].to_owned()))
  }
  prefix.push(Hir::alternation(suffix_alts))
  Some(Hir::concat(prefix))
}

///|
/// The kind of `.` to build.
pub(all) enum Dot {
  AnyChar
  AnyByte
  AnyCharExcept(Int32)
  AnyCharExceptLF
  AnyCharExceptCRLF
  AnyByteExcept(Int32)
  AnyByteExceptLF
  AnyByteExceptCRLF
}

///|
pub fn Hir::dot(dot : Dot) -> Hir {
  match dot {
    AnyChar => Hir::class(Unicode([(0, 0x10FFFF)]))
    AnyByte => Hir::class(Bytes([(0, 0xFF)]))
    AnyCharExcept(c) => Hir::class(Unicode(ranges_negate([(c, c)], true)))
    AnyCharExceptLF => Hir::class(Unicode([(0, 9), (0xB, 0x10FFFF)]))
    AnyCharExceptCRLF =>
      Hir::class(Unicode([(0, 9), (0xB, 0xC), (0xE, 0x10FFFF)]))
    AnyByteExcept(b) => Hir::class(Bytes(ranges_negate([(b, b)], false)))
    AnyByteExceptLF => Hir::class(Bytes([(0, 9), (0xB, 0xFF)]))
    AnyByteExceptCRLF => Hir::class(Bytes([(0, 9), (0xB, 0xC), (0xE, 0xFF)]))
  }
}

///|
pub fn Hir::is_empty_kind(self : Hir) -> Bool {
  self.kind is Empty
}
