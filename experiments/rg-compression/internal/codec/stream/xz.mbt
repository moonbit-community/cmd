///|
priv enum XzPhase { Header; BlockStart; BlockHeader; Control; ChunkHeader; RawChunk; CompressedChunk; Padding; Check; Index; IndexCrc; Footer; StreamPadding }

///|
priv struct XzState {
  mut phase : XzPhase
  bytes : FixedArray[Byte]
  mut have : Int
  mut needed : Int
  mut check_id : Int
  mut check_size : Int
  mut crc32 : @crc.Crc32
  mut crc64 : UInt64
  mut sha : @crypto.SHA256
  mut actual_index : @crypto.SHA256
  mut read_index : @crypto.SHA256
  mut index_crc : @crc.Crc32
  mut lzma : LzmaState
  mut dictionary_required : Bool
  mut properties_required : Bool
  mut state_required : Bool
  mut control : Int
  mut remaining : Int
  mut header_size : Int
  mut compressed : Int64
  mut uncompressed : Int64
  mut declared_compressed : Int64?
  mut declared_uncompressed : Int64?
  mut blocks : Int64
  mut index_size : Int64
  mut index_fields : Int64
  mut index_unpadded : Int64
  mut vli : UInt64
  mut vli_shift : Int
  mut padding : Int
  mut any_stream : Bool
}

///|
fn XzState::new() -> XzState {
  { phase: Header, bytes: FixedArray::make(1024, b'\x00'), have: 0, needed: 12,
    check_id: 0, check_size: 0, crc32: @crc.Crc32(), crc64: 0xffffffffffffffffUL,
    sha: @crypto.SHA256::new(), actual_index: @crypto.SHA256::new(), read_index: @crypto.SHA256::new(),
    index_crc: @crc.Crc32(), lzma: LzmaState::new(), dictionary_required: true,
    properties_required: true, state_required: true, control: 0, remaining: 0,
    header_size: 0, compressed: 0L, uncompressed: 0L, declared_compressed: None,
    declared_uncompressed: None, blocks: 0L, index_size: 0L, index_fields: -1L,
    index_unpadded: 0L, vli: 0UL, vli_shift: 0, padding: 0, any_stream: false }
}

///|
fn xz_u32(bytes : FixedArray[Byte], at : Int) -> UInt {
  bytes[at].to_uint() | (bytes[at + 1].to_uint() << 8) |
    (bytes[at + 2].to_uint() << 16) | (bytes[at + 3].to_uint() << 24)
}

///|
fn xz_vli(bytes : FixedArray[Byte], pos : Ref[Int], limit : Int) -> Int64 raise DecodeError {
  let mut value = 0UL
  for i in 0..<9 {
    guard pos.val < limit else { raise DecodeError("truncated XZ variable integer") }
    let byte = bytes[pos.val].to_int()
    pos.val += 1
    value = value | ((byte & 127).to_uint64() << (i * 7))
    if byte < 128 {
      if i > 0 && byte == 0 { raise DecodeError("noncanonical XZ variable integer") }
      return value.reinterpret_as_int64()
    }
  }
  raise DecodeError("XZ variable integer overflow")
}

///|
fn xz_hash_pair(hash : @crypto.SHA256, first : Int64, second : Int64) -> Unit {
  let bytes = FixedArray::make(16, b'\x00')
  for i in 0..<8 {
    bytes[i] = (first.reinterpret_as_uint64() >> (i * 8)).to_byte()
    bytes[8 + i] = (second.reinterpret_as_uint64() >> (i * 8)).to_byte()
  }
  hash.update(bytes)
}

///|
fn XzState::collect(self : XzState, input : BytesView, ip : Ref[Int], needed : Int) -> Bool {
  while self.have < needed && ip.val < input.length() {
    self.bytes[self.have] = input[ip.val]
    self.have += 1
    ip.val += 1
  }
  self.have == needed
}

///|
fn XzState::block_header(self : XzState) -> Unit raise DecodeError {
  let bytes = self.bytes.unsafe_reinterpret_as_bytes()
  guard @crc.crc32(bytes[:self.needed - 4]) == xz_u32(self.bytes, self.needed - 4) else {
    raise DecodeError("XZ block header checksum mismatch")
  }
  let flags = self.bytes[1].to_int()
  guard (flags & 60) == 0 else { raise DecodeError("reserved XZ block flags") }
  let filters = (flags & 3) + 1
  let pos = Ref(2)
  self.declared_compressed = if (flags & 64) != 0 { Some(xz_vli(self.bytes, pos, self.needed - 4)) } else { None }
  self.declared_uncompressed = if (flags & 128) != 0 { Some(xz_vli(self.bytes, pos, self.needed - 4)) } else { None }
  for index in 0..<filters {
    let id = xz_vli(self.bytes, pos, self.needed - 4)
    let length = xz_vli(self.bytes, pos, self.needed - 4)
    guard length <= (self.needed - 4 - pos.val).to_int64() else { raise DecodeError("invalid XZ filter properties length") }
    if index != filters - 1 { raise DecodeError("XZ filter-chain migration incomplete") }
    guard id == 33L && length == 1L else { raise DecodeError("XZ final filter must be LZMA2") }
    let property = self.bytes[pos.val].to_int()
    guard property < 40 else { raise DecodeError("XZ dictionary exceeds representable buffer length") }
    let size = (2UL | (property & 1).to_uint64()) << (property / 2 + 11)
    guard size <= 2147483647UL else { raise DecodeError("XZ dictionary exceeds representable buffer length") }
    self.lzma = LzmaState::new()
    self.lzma.configure(0, size.to_uint())
    pos.val += 1
  }
  while pos.val < self.needed - 4 {
    guard self.bytes[pos.val] == b'\x00' else { raise DecodeError("nonzero XZ header padding") }
    pos.val += 1
  }
  self.header_size = self.needed
  self.compressed = 0L
  self.uncompressed = 0L
  self.crc32 = @crc.Crc32()
  self.crc64 = 0xffffffffffffffffUL
  self.sha = @crypto.SHA256::new()
  self.dictionary_required = true
  self.properties_required = true
  self.state_required = true
}

///|
fn XzState::checksum(self : XzState, output : MutArrayView[Byte], start : Int, count : Int) -> Unit raise DecodeError {
  guard self.uncompressed <= 9223372036854775807L - count.to_int64() else { raise DecodeError("XZ output size overflow") }
  self.uncompressed += count.to_int64()
  if self.check_id == 10 { self.sha.update(Bytes::makei(count, i => output[start + i])) }
  for i in start..<(start + count) {
    let byte = output[i]
    if self.check_id == 1 { self.crc32.update_byte(byte) }
    if self.check_id == 4 {
      self.crc64 = self.crc64 ^ byte.to_uint64()
      for _ in 0..<8 {
        self.crc64 = (self.crc64 >> 1) ^ (if (self.crc64 & 1UL) != 0UL { 0xc96c5795d7870f42UL } else { 0UL })
      }
    }
  }
}

///|
fn XzState::step(self : XzState, input : BytesView, output : MutArrayView[Byte], end~ : Bool) -> Step {
  let ip = Ref(0)
  let mut op = 0
  fn result(status : Status) -> Step { { consumed: ip.val, produced: op, status } }
  fn need_input() -> Step { result(if end { Failed("truncated XZ stream") } else { NeedInput }) }
  try {
    for ;; {
      match self.phase {
        Header => {
          if !self.collect(input, ip, 12) { return need_input() }
          guard self.bytes.unsafe_reinterpret_as_bytes()[:6] == b"\xfd7zXZ\x00" else { raise DecodeError("invalid XZ stream magic") }
          guard self.bytes[6] == b'\x00' else { raise DecodeError("reserved XZ stream flags") }
          self.check_id = self.bytes[7].to_int()
          self.check_size = match self.check_id { 0 => 0; 1 => 4; 4 => 8; 10 => 32; _ => raise DecodeError("unsupported XZ integrity check ID") }
          guard @crc.crc32(self.bytes.unsafe_reinterpret_as_bytes()[6:8]) == xz_u32(self.bytes, 8) else { raise DecodeError("XZ stream header checksum mismatch") }
          self.blocks = 0L
          self.actual_index = @crypto.SHA256::new()
          self.read_index = @crypto.SHA256::new()
          self.have = 0
          self.phase = BlockStart
        }
        BlockStart => {
          if !self.collect(input, ip, 1) { return need_input() }
          if self.bytes[0] == b'\x00' {
            self.index_crc = @crc.Crc32()
            self.index_crc.update_byte(b'\x00')
            self.index_size = 1L
            self.index_fields = -1L
            self.vli = 0UL; self.vli_shift = 0
            self.phase = Index
            self.have = 0
          } else {
            self.needed = (self.bytes[0].to_int() + 1) * 4
            self.phase = BlockHeader
          }
        }
        BlockHeader => {
          if !self.collect(input, ip, self.needed) { return need_input() }
          self.block_header()
          self.have = 0
          self.phase = Control
        }
        Control => {
          if !self.collect(input, ip, 1) { return need_input() }
          self.control = self.bytes[0].to_int()
          self.compressed += 1L
          self.have = 0
          if self.control == 0 {
            if self.declared_compressed is Some(size) && size != self.compressed { raise DecodeError("XZ compressed size mismatch") }
            if self.declared_uncompressed is Some(size) && size != self.uncompressed { raise DecodeError("XZ uncompressed size mismatch") }
            self.padding = (4 - (self.compressed.to_int() & 3)) & 3
            self.phase = Padding
          } else {
            if self.control >= 3 && self.control < 128 { raise DecodeError("invalid LZMA2 control byte") }
            if (self.control == 1 || self.control >= 224) {
              self.lzma.reset_dictionary()
              self.dictionary_required = false
            }
            if self.dictionary_required { raise DecodeError("LZMA2 dictionary reset required") }
            self.needed = if self.control < 128 { 2 } else if self.control >= 192 { 5 } else { 4 }
            self.phase = ChunkHeader
          }
        }
        ChunkHeader => {
          if !self.collect(input, ip, self.needed) { return need_input() }
          self.compressed += self.needed.to_int64()
          let usize = (self.bytes[0].to_int() << 8) + self.bytes[1].to_int() + 1
          if self.control < 128 {
            self.remaining = usize
            self.lzma.expected = None
            self.state_required = true
            self.phase = RawChunk
          } else {
            let usize = usize + ((self.control & 31) << 16)
            self.remaining = (self.bytes[2].to_int() << 8) + self.bytes[3].to_int() + 1
            if self.control >= 192 {
              self.lzma.properties(self.bytes[4].to_int())
              guard self.lzma.lc + self.lzma.lp <= 4 else { raise DecodeError("invalid LZMA2 literal properties") }
              self.properties_required = false
            }
            if self.properties_required { raise DecodeError("LZMA2 properties required") }
            if self.control >= 160 { self.lzma.reset_models(); self.state_required = false }
            if self.state_required { raise DecodeError("LZMA2 state reset required") }
            self.lzma.expected = Some(self.lzma.total + usize.to_int64())
            self.lzma.range = 0xffffffffU; self.lzma.code = 0U
            self.lzma.range_ready = false; self.lzma.queued = 0; self.lzma.ended = false
            self.phase = CompressedChunk
          }
          self.have = 0
        }
        RawChunk => {
          let count = self.remaining.min(input.length() - ip.val).min(output.length() - op)
          for i in 0..<count {
            let byte = input[ip.val + i]
            self.lzma.emit(byte)
            output[op + i] = byte
          }
          self.checksum(output, op, count)
          op += count; ip.val += count
          self.compressed += count.to_int64(); self.remaining -= count
          if self.remaining == 0 { self.phase = Control }
          else if op == output.length() { return result(NeedOutput) }
          else { return need_input() }
        }
        CompressedChunk => {
          if op == output.length() { return result(NeedOutput) }
          let count = self.remaining.min(input.length() - ip.val)
          let step = self.lzma.raw_step(input[ip.val:ip.val + count], output.mut_view(start=op), end=count == self.remaining)
          self.checksum(output, op, step.produced)
          op += step.produced; ip.val += step.consumed
          self.remaining -= step.consumed; self.compressed += step.consumed.to_int64()
          match step.status {
            Failed(message) => return result(Failed(message))
            Done => {
              if self.remaining != 0 { raise DecodeError("unused LZMA2 compressed bytes") }
              self.phase = Control
            }
            NeedInput => return need_input()
            NeedOutput => return result(NeedOutput)
          }
        }
        Padding => {
          while self.padding > 0 {
            if ip.val == input.length() { return need_input() }
            if input[ip.val] != b'\x00' { raise DecodeError("nonzero XZ block padding") }
            ip.val += 1; self.padding -= 1
          }
          self.have = 0
          self.phase = Check
        }
        Check => {
          if !self.collect(input, ip, self.check_size) { return need_input() }
          let expected = match self.check_id {
            0 => b""
            1 => Bytes::makei(4, i => (self.crc32.finish() >> (i * 8)).to_byte())
            4 => Bytes::makei(8, i => ((self.crc64 ^ 0xffffffffffffffffUL) >> (i * 8)).to_byte())
            _ => Bytes::from_array(self.sha.finalize()[:])
          }
          if self.bytes.unsafe_reinterpret_as_bytes()[:self.check_size] != expected { raise DecodeError("XZ block checksum mismatch") }
          xz_hash_pair(self.actual_index, self.header_size.to_int64() + self.compressed + self.check_size.to_int64(), self.uncompressed)
          self.blocks += 1L
          self.have = 0
          self.phase = BlockStart
        }
        Index => {
          if ip.val == input.length() { return need_input() }
          let byte = input[ip.val].to_int()
          ip.val += 1; self.index_size += 1L
          self.index_crc.update_byte(byte.to_byte())
          if self.index_fields == 0L {
            if byte != 0 { raise DecodeError("nonzero XZ index padding") }
          } else {
            if self.vli_shift >= 63 { raise DecodeError("XZ index integer overflow") }
            self.vli = self.vli | ((byte & 127).to_uint64() << self.vli_shift)
            if byte < 128 {
              if self.vli_shift > 0 && byte == 0 { raise DecodeError("noncanonical XZ index integer") }
              let value = self.vli.reinterpret_as_int64()
              if self.index_fields == -1L {
                if value != self.blocks { raise DecodeError("XZ index record count mismatch") }
                guard value <= 4611686018427387903L else { raise DecodeError("XZ index record count overflow") }
                self.index_fields = value * 2L
              } else {
                if (self.index_fields & 1L) == 0L { self.index_unpadded = value }
                else { xz_hash_pair(self.read_index, self.index_unpadded, value) }
                self.index_fields -= 1L
              }
              self.vli = 0UL; self.vli_shift = 0
            } else { self.vli_shift += 7 }
          }
          if self.index_fields == 0L && (self.index_size & 3L) == 0L { self.phase = IndexCrc; self.have = 0 }
        }
        IndexCrc => {
          if !self.collect(input, ip, 4) { return need_input() }
          if xz_u32(self.bytes, 0) != self.index_crc.finish() { raise DecodeError("XZ index checksum mismatch") }
          if self.actual_index.finalize() != self.read_index.finalize() { raise DecodeError("XZ index records do not match decoded blocks") }
          self.index_size += 4L
          self.phase = Footer; self.have = 0
        }
        Footer => {
          if !self.collect(input, ip, 12) { return need_input() }
          if xz_u32(self.bytes, 0) != @crc.crc32(self.bytes.unsafe_reinterpret_as_bytes()[4:10]) { raise DecodeError("XZ footer checksum mismatch") }
          if xz_u32(self.bytes, 4).to_uint64() != (self.index_size / 4L - 1L).reinterpret_as_uint64() { raise DecodeError("XZ backward index size mismatch") }
          if self.bytes[8] != b'\x00' || self.bytes[9].to_int() != self.check_id || self.bytes[10] != b'Y' || self.bytes[11] != b'Z' { raise DecodeError("invalid XZ footer flags or magic") }
          self.phase = StreamPadding; self.padding = 0; self.have = 0; self.any_stream = true
        }
        StreamPadding => {
          while ip.val < input.length() && input[ip.val] == b'\x00' { ip.val += 1; self.padding = (self.padding + 1) & 3 }
          if ip.val == input.length() {
            if end && self.any_stream && self.padding == 0 { return result(Done) }
            return need_input()
          }
          if self.padding != 0 { raise DecodeError("XZ stream padding is not a multiple of four") }
          self.phase = Header; self.have = 0
        }
      }
    }
  } catch { DecodeError(message) => result(Failed(message)) }
}
