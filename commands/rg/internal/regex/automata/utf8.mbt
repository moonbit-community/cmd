///|
/// Returns the sequences of byte ranges matching the UTF-8 encodings of all
/// scalar values in `start..=end` (surrogates excluded). Each sequence is an
/// array of 1 to 4 inclusive byte ranges.
pub fn utf8_sequences(
  start : Int32,
  end : Int32,
) -> Array[Array[(Int32, Int32)]] {
  let out = []
  let stack = [(start, end)]
  while stack.pop() is Some((s0, e0)) {
    let s = s0
    let mut e = e0
    let mut done = false
    while !done {
      // Split around the surrogate range.
      if s < 0xE000 && e > 0xD7FF {
        stack.push((0xE000, e))
        e = 0xD7FF
        continue
      }
      if s > e {
        done = true
        continue
      }
      let mut split = false
      for i in 1..<4 {
        let max = max_scalar_value(i)
        if s <= max && max < e {
          stack.push((max + 1, e))
          e = max
          split = true
          break
        }
      }
      if split {
        continue
      }
      if e <= 0x7F {
        out.push([(s, e)])
        done = true
        continue
      }
      for i in 1..<4 {
        let m = (1 << (6 * i)) - 1
        if (s & m.lnot()) != (e & m.lnot()) {
          if (s & m) != 0 {
            stack.push(((s | m) + 1, e))
            e = s | m
            split = true
            break
          }
          if (e & m) != m {
            stack.push((e & m.lnot(), e))
            e = (e & m.lnot()) - 1
            split = true
            break
          }
        }
      }
      if split {
        continue
      }
      let sb = encode_utf8_array(s)
      let eb = encode_utf8_array(e)
      let seq = []
      for j in 0..<sb.length() {
        seq.push((sb[j], eb[j]))
      }
      out.push(seq)
      done = true
    }
  }
  out
}

///|
fn max_scalar_value(nbytes : Int32) -> Int32 {
  match nbytes {
    1 => 0x7F
    2 => 0x7FF
    3 => 0xFFFF
    _ => 0x10FFFF
  }
}

///|
fn encode_utf8_array(c : Int32) -> Array[Int32] {
  if c < 0x80 {
    [c]
  } else if c < 0x800 {
    [0xC0 | (c >> 6), 0x80 | (c & 0x3F)]
  } else if c < 0x10000 {
    [0xE0 | (c >> 12), 0x80 | ((c >> 6) & 0x3F), 0x80 | (c & 0x3F)]
  } else {
    [
      0xF0 | (c >> 18),
      0x80 | ((c >> 12) & 0x3F),
      0x80 | ((c >> 6) & 0x3F),
      0x80 | (c & 0x3F),
    ]
  }
}

///|
/// A node in the UTF-8 compiler's uncompiled trie.
priv struct Utf8Node {
  trans : Array[Transition]
  mut last : (Int32, Int32)?
}

///|
fn Utf8Node::set_last_transition(self : Utf8Node, next : Int32) -> Unit {
  if self.last is Some((s, e)) {
    self.trans.push({ start: s, end: e, next, })
    self.last = None
  }
}

///|
/// Compiles a sorted sequence of UTF-8 range sequences into a compact
/// automaton, sharing common prefixes and suffixes.
priv struct Utf8Compiler {
  builder : Builder
  compiled : Map[String, Int32]
  uncompiled : Array[Utf8Node]
  target : Int32
}

///|
fn Utf8Compiler::new(builder : Builder) -> Utf8Compiler {
  let target = builder.add_empty()
  let c = { builder, compiled: {}, uncompiled: [], target, }
  c.uncompiled.push({ trans: [], last: None, })
  c
}

///|
fn Utf8Compiler::finish(self : Utf8Compiler) -> ThompsonRef {
  self.compile_from(0)
  let node = self.uncompiled.pop().unwrap()
  let start = self.compile(node.trans)
  { start, end: self.target, }
}

///|
fn Utf8Compiler::add(
  self : Utf8Compiler,
  ranges : Array[(Int32, Int32)],
) -> Unit {
  let mut prefix_len = 0
  while prefix_len < ranges.length() && prefix_len < self.uncompiled.length() {
    match self.uncompiled[prefix_len].last {
      Some(t) if t == ranges[prefix_len] => prefix_len += 1
      _ => break
    }
  }
  self.compile_from(prefix_len)
  // add suffix
  let last = self.uncompiled.length() - 1
  self.uncompiled[last].last = Some(ranges[prefix_len])
  for i in (prefix_len + 1)..<ranges.length() {
    self.uncompiled.push({ trans: [], last: Some(ranges[i]), })
  }
}

///|
fn Utf8Compiler::compile_from(self : Utf8Compiler, from : Int32) -> Unit {
  let mut next = self.target
  while from + 1 < self.uncompiled.length() {
    let node = self.uncompiled.pop().unwrap()
    node.set_last_transition(next)
    next = self.compile(node.trans)
  }
  self.uncompiled[self.uncompiled.length() - 1].set_last_transition(next)
}

///|
fn Utf8Compiler::compile(
  self : Utf8Compiler,
  trans : Array[Transition],
) -> Int32 {
  let key = StringBuilder()
  for t in trans {
    key.write_string("\{t.start},\{t.end},\{t.next};")
  }
  let k = key.to_string()
  match self.compiled.get(k) {
    Some(id) => id
    None => {
      let id = self.builder.add_sparse(trans.copy())
      self.compiled[k] = id
      id
    }
  }
}
