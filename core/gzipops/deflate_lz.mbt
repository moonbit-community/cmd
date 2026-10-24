///|
priv enum DeflateToken {
  Literal(Byte)
  Copy(Int32, Int32)
}

///|
priv struct DeflateLz {
  literals : FixedArray[DeflateToken]
  heads : FixedArray[Int64]
  previous : FixedArray[Int64]
  chain_limit : Int32
  nice_length : Int32
  lazy_match : Bool
  mut history : Bytes
  mut offset : Int64
  mut next_insert : Int64
}

///|
fn DeflateLz::new(level : Int32) -> DeflateLz {
  let chains : ReadOnlyArray[Int32] = [4, 8, 16, 32, 64, 128, 256, 512, 1024]
  let nice : ReadOnlyArray[Int32] = [16, 32, 64, 64, 128, 128, 258, 258, 258]
  {
    literals: FixedArray::makei(256, byte => Literal(byte.to_byte())),
    heads: FixedArray::make(32768, -1L),
    previous: FixedArray::make(32768, -1L),
    chain_limit: chains[level - 1],
    nice_length: nice[level - 1],
    lazy_match: level >= 4,
    history: b"",
    offset: 0L,
    next_insert: 0L,
  }
}

///|
fn deflate_hash(input : Bytes, index : Int32) -> Int32 {
  (
    (input[index].to_int() << 10) ^
    (input[index + 1].to_int() << 5) ^
    input[index + 2].to_int()
  ) &
  32767
}

///|
// Leave the final two positions pending until another chunk supplies lookahead.
// Calling this after a copy also indexes every position skipped by that token.
fn DeflateLz::insert_before(
  self : DeflateLz,
  input : Bytes,
  base : Int64,
  position : Int64,
  end : Int64,
) -> Unit {
  while self.next_insert < position && self.next_insert + 2L < end {
    let slot = (self.next_insert & 32767L).to_int()
    let hash = deflate_hash(input, (self.next_insert - base).to_int())
    self.previous[slot] = self.heads[hash]
    self.heads[hash] = self.next_insert
    self.next_insert += 1L
  }
}

///|
fn DeflateLz::find(
  self : DeflateLz,
  input : Bytes,
  base : Int64,
  position : Int64,
  end : Int64,
) -> (Int32, Int32) {
  let limit = (end - position).min(258L).to_int()
  if limit < 3 {
    return (0, 0)
  }
  let index = (position - base).to_int()
  let oldest = (position - 32768L).max(base)
  let mut candidate = self.heads[deflate_hash(input, index)]
  let mut searched = 0
  let mut best = 2
  let mut distance = 0
  while candidate >= oldest && searched < self.chain_limit {
    let prior = (candidate - base).to_int()
    // A known mismatching byte avoids rescanning a shorter hash collision.
    if input[prior + best] == input[index + best] {
      let mut length = 0
      while length < limit && input[prior + length] == input[index + length] {
        length += 1
      }
      if length > best {
        best = length
        distance = (position - candidate).to_int()
        if best >= self.nice_length || best == limit {
          break
        }
      }
    }
    candidate = self.previous[(candidate & 32767L).to_int()]
    searched += 1
  }
  if best >= 3 {
    (best, distance)
  } else {
    (0, 0)
  }
}

///|
// Each input chunk is at most 64 KiB. Only its preceding 32 KiB is retained;
// absolute positions remain Int64 while ring indices are masked before casting.
fn DeflateLz::tokenize(self : DeflateLz, input : Bytes) -> Array[DeflateToken] {
  if input.is_empty() {
    return []
  }
  let bytes = self.history + input
  let base = self.offset - self.history.length().to_int64()
  let end = self.offset + input.length().to_int64()
  let tokens : Array[DeflateToken] = []
  let mut position = self.offset
  while position < end {
    self.insert_before(bytes, base, position, end)
    // Search before inserting this position: its ring slot may still hold the
    // valid candidate at the inclusive 32768-byte distance.
    let (length, distance) = self.find(bytes, base, position, end)
    if self.lazy_match && length >= 3 {
      self.insert_before(bytes, base, position + 1L, end)
      let (next_length, _) = self.find(bytes, base, position + 1L, end)
      if next_length > length {
        tokens.push(self.literals[bytes[(position - base).to_int()].to_int()])
        position += 1L
        continue
      }
    }
    if length >= 3 {
      tokens.push(Copy(length, distance))
      position += length.to_int64()
    } else {
      tokens.push(self.literals[bytes[(position - base).to_int()].to_int()])
      position += 1L
    }
  }
  self.insert_before(bytes, base, end, end)
  self.history = bytes[(bytes.length() - 32768).max(0):].to_owned()
  self.offset = end
  tokens
}
