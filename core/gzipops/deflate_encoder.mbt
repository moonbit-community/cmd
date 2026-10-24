///|
priv enum DeflateBlock {
  Stored
  Fixed
  Dynamic(DeflateDynamic)
}

///|
priv struct DeflateEncoder {
  bits : DeflateBits
  lz : DeflateLz
  fixed : DeflateTable
  mut open : DeflateTable?
}

///|
fn DeflateEncoder::new(level : Int32) -> DeflateEncoder {
  {
    bits: DeflateBits::new(),
    lz: DeflateLz::new(level),
    fixed: deflate_fixed_table(),
    open: None,
  }
}

///|
fn deflate_finished_cost(
  bits : Int32,
  pending : Int32,
  finish~ : Bool,
) -> Int32 {
  bits + (if finish { (8 - (pending + bits) % 8) % 8 } else { 0 })
}

///|
fn DeflateEncoder::close_block(self : DeflateEncoder) -> Unit {
  if self.open is Some(table) {
    self.bits.code(table.literal[256])
    self.open = None
  }
}

///|
// A chunk can extend an open Huffman block when its alphabet still fits. This
// avoids a new dynamic-tree header for every 64 KiB of a long repeated input.
fn DeflateEncoder::push(
  self : DeflateEncoder,
  input : Bytes,
  finish~ : Bool,
) -> Bytes {
  if input.is_empty() {
    if finish {
      self.close_block()
      self.bits.put(3U, 3)
      self.bits.code(self.fixed.literal[256])
      self.bits.align()
    }
    return self.bits.drain()
  }
  let tokens = self.lz.tokenize(input)
  let dynamic = deflate_dynamic(tokens)
  let close = match self.open {
    Some(table) => table.literal[256].length
    None => 0
  }
  let start = (self.bits.count + close) % 8
  let fixed_bits = 3 + deflate_token_bits(self.fixed, tokens).unwrap()
  let dynamic_bits = dynamic.header_bits +
    deflate_token_bits(dynamic.table, tokens).unwrap()
  let mut block = Fixed
  let mut cost = deflate_finished_cost(fixed_bits, start, finish~)
  let candidate = deflate_finished_cost(dynamic_bits, start, finish~)
  if candidate < cost {
    block = Dynamic(dynamic)
    cost = candidate
  }
  let stored = deflate_stored_bits(input.length(), start)
  if stored < cost {
    block = Stored
    cost = stored
  }
  if self.open is Some(table) && deflate_token_bits(table, tokens) is Some(bits) {
    // An already emitted non-final header needs an empty final block at EOF.
    let reuse = deflate_finished_cost(
      bits + (if finish { 10 } else { 0 }),
      self.bits.count,
      finish~,
    )
    if reuse <= close + cost {
      self.bits.tokens(table, tokens)
      if finish {
        self.close_block()
        self.bits.put(3U, 3)
        self.bits.code(self.fixed.literal[256])
        self.bits.align()
      }
      return self.bits.drain()
    }
  }
  self.close_block()
  match block {
    Stored => self.bits.stored(input[:], finish~)
    Fixed => {
      self.bits.put(if finish { 3U } else { 2U }, 3)
      self.bits.tokens(self.fixed, tokens)
      self.open = Some(self.fixed)
    }
    Dynamic(plan) => {
      self.bits.dynamic_header(plan, finish~)
      self.bits.tokens(plan.table, tokens)
      self.open = Some(plan.table)
    }
  }
  if finish {
    self.close_block()
    self.bits.align()
  }
  self.bits.drain()
}
