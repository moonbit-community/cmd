// Streaming WHATWG decoders (UTF-8, UTF-16 and the legacy encodings), following the
// Encoding Standard's decoder handlers (and thus encoding_rs) exactly,
// including U+FFFD error replacement and "restore byte to the stream"
// semantics.

///|
// ISO-2022-JP decoder states.
const ISO2022_ASCII : Int32 = 0

///|
const ISO2022_ROMAN : Int32 = 1

///|
const ISO2022_KATAKANA : Int32 = 2

///|
const ISO2022_LEAD : Int32 = 3

///|
const ISO2022_TRAIL : Int32 = 4

///|
const ISO2022_ESCAPE_START : Int32 = 5

///|
const ISO2022_ESCAPE : Int32 = 6

///|
/// End-of-stream marker passed to the handlers.
const EOS : Int32 = -1

///|
/// State of a legacy decoder. Bytes "restored to the stream" by a handler are
/// kept on a small stack and processed before the next input byte, so the
/// decoder works no matter how the input is split into chunks.
priv struct LegacyDecoder {
  kind : EncKind
  // Single-byte table (for SingleByte kinds).
  table : FixedArray[Int32]
  // Lead byte (gb18030 first, Big5/EUC-JP/Shift_JIS/EUC-KR/ISO-2022-JP lead).
  mut lead : Int32
  // gb18030 second and third bytes.
  mut second : Int32
  mut third : Int32
  // EUC-JP jis0212 flag.
  mut jis0212 : Bool
  // ISO-2022-JP decoder state, output state and output flag.
  mut state : Int32
  mut out_state : Int32
  mut output : Bool
  // Restored bytes, top of stack is processed next.
  pending : FixedArray[Int32]
  mut npending : Int32
  // UTF-8 decoder state.
  mut u8_cp : Int32
  mut u8_seen : Int32
  mut u8_needed : Int32
  mut u8_lower : Int32
  mut u8_upper : Int32
  // UTF-16 decoder state (-1 when unset).
  mut u16_lead_byte : Int32
  mut u16_lead_surrogate : Int32
  // BOM removal (encoding_rs's `new_decoder_with_bom_removal`): the number
  // of bytes of this encoding's BOM matched so far, or -1 once decided.
  bom : FixedArray[Int32]
  mut bom_state : Int32
}

///|
fn LegacyDecoder::new(
  kind : EncKind,
  bom_removal~ : Bool = false,
) -> LegacyDecoder {
  let table = match kind {
    SingleByte(i) => single_byte_indexes[i].get()
    _ => FixedArray::make(0, 0)
  }
  // Only the UTF encodings have a BOM to remove.
  let bom : FixedArray[Int32] = match kind {
    Utf8 if bom_removal => [0xEF, 0xBB, 0xBF]
    Utf16LE if bom_removal => [0xFF, 0xFE]
    Utf16BE if bom_removal => [0xFE, 0xFF]
    _ => []
  }
  {
    kind,
    table,
    lead: 0,
    second: 0,
    third: 0,
    jis0212: false,
    state: ISO2022_ASCII,
    out_state: ISO2022_ASCII,
    output: false,
    pending: FixedArray::make(4, 0),
    npending: 0,
    u8_cp: 0,
    u8_seen: 0,
    u8_needed: 0,
    u8_lower: 0x80,
    u8_upper: 0xBF,
    u16_lead_byte: -1,
    u16_lead_surrogate: -1,
    bom,
    bom_state: if bom.length() > 0 {
      0
    } else {
      -1
    },
  }
}

///|
/// Restores `b` to the front of the input stream.
fn LegacyDecoder::restore(self : LegacyDecoder, b : Int32) -> Unit {
  self.pending[self.npending] = b
  self.npending += 1
}

///|
fn LegacyDecoder::drain(self : LegacyDecoder, out : Buffer) -> Unit {
  while self.npending > 0 {
    self.npending -= 1
    ignore(self.handle(self.pending[self.npending], out))
  }
}

///|
/// Decodes `raw[start:end]` into `out`.
fn LegacyDecoder::feed(
  self : LegacyDecoder,
  raw : FixedArray[Byte],
  start : Int32,
  end : Int32,
  out : Buffer,
) -> Unit {
  let mut start = start
  // Remove this encoding's BOM at the start of the stream (it may be split
  // across chunks); on a mismatch the matched prefix is decoded normally.
  while self.bom_state >= 0 && start < end {
    if raw[start].to_int() == self.bom[self.bom_state] {
      self.bom_state += 1
      start += 1
      if self.bom_state == self.bom.length() {
        self.bom_state = -1
      }
    } else {
      self.replay_bom_prefix(out)
    }
  }
  match self.kind {
    SingleByte(_) =>
      for i in start..<end {
        let b = raw[i].to_int()
        if b < 0x80 {
          out.write_byte(raw[i])
        } else {
          let c = self.table[b - 0x80]
          push_char(out, if c < 0 { 0xFFFD } else { c })
        }
      }
    XUserDefined =>
      for i in start..<end {
        let b = raw[i].to_int()
        if b < 0x80 {
          out.write_byte(raw[i])
        } else {
          push_char(out, 0xF780 + b - 0x80)
        }
      }
    _ =>
      for i in start..<end {
        ignore(self.handle(raw[i].to_int(), out))
        self.drain(out)
      }
  }
}

///|
/// Decodes the bytes of a partially matched BOM normally (they turned out
/// not to be a BOM), and stops looking for one.
fn LegacyDecoder::replay_bom_prefix(self : LegacyDecoder, out : Buffer) -> Unit {
  let n = self.bom_state
  self.bom_state = -1
  for i in 0..<n {
    ignore(self.handle(self.bom[i], out))
    self.drain(out)
  }
}

///|
/// Handles a decode call with empty input that isn't the last one. This is
/// a no-op except that, like encoding_rs, the Shift_JIS, EUC-KR and Big5
/// decoders forget a pending lead byte (so it is not reported at the end).
fn LegacyDecoder::decode_empty(self : LegacyDecoder) -> Unit {
  match self.kind {
    ShiftJis | EucKr | Big5 => self.lead = 0
    _ => ()
  }
}

///|
/// Processes the end of the stream.
fn LegacyDecoder::finish(self : LegacyDecoder, out : Buffer) -> Unit {
  if self.bom_state >= 0 {
    self.replay_bom_prefix(out)
  }
  for ;; {
    let finished = self.handle(EOS, out)
    self.drain(out)
    if finished {
      break
    }
  }
}

///|
/// Runs the decoder's handler on `b` (a byte or `EOS`), writing any output
/// to `out`. Returns true when the handler returns "finished".
fn LegacyDecoder::handle(self : LegacyDecoder, b : Int32, out : Buffer) -> Bool {
  match self.kind {
    Gbk | Gb18030 => self.handle_gb18030(b, out)
    Big5 => self.handle_big5(b, out)
    EucJp => self.handle_euc_jp(b, out)
    Iso2022Jp => self.handle_iso2022jp(b, out)
    ShiftJis => self.handle_shift_jis(b, out)
    EucKr => self.handle_euc_kr(b, out)
    SingleByte(_) =>
      if b == EOS {
        true
      } else {
        if b < 0x80 {
          push_char(out, b)
        } else {
          let c = self.table[b - 0x80]
          push_char(out, if c < 0 { 0xFFFD } else { c })
        }
        false
      }
    XUserDefined =>
      if b == EOS {
        true
      } else {
        push_char(out, if b < 0x80 { b } else { 0xF780 + b - 0x80 })
        false
      }
    Utf8 => self.handle_utf8(b, out)
    Utf16LE => self.handle_utf16(b, false, out)
    Utf16BE => self.handle_utf16(b, true, out)
  }
}

///|
/// The Encoding Standard's UTF-8 decoder handler.
fn LegacyDecoder::handle_utf8(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.u8_needed != 0 {
      self.u8_needed = 0
      push_error(out)
      return false
    }
    return true
  }
  if self.u8_needed == 0 {
    if b < 0x80 {
      push_char(out, b)
    } else if b >= 0xC2 && b <= 0xDF {
      self.u8_needed = 1
      self.u8_cp = b & 0x1F
    } else if b >= 0xE0 && b <= 0xEF {
      if b == 0xE0 {
        self.u8_lower = 0xA0
      }
      if b == 0xED {
        self.u8_upper = 0x9F
      }
      self.u8_needed = 2
      self.u8_cp = b & 0xF
    } else if b >= 0xF0 && b <= 0xF4 {
      if b == 0xF0 {
        self.u8_lower = 0x90
      }
      if b == 0xF4 {
        self.u8_upper = 0x8F
      }
      self.u8_needed = 3
      self.u8_cp = b & 0x7
    } else {
      push_error(out)
    }
    return false
  }
  if b < self.u8_lower || b > self.u8_upper {
    self.u8_cp = 0
    self.u8_needed = 0
    self.u8_seen = 0
    self.u8_lower = 0x80
    self.u8_upper = 0xBF
    self.restore(b)
    push_error(out)
    return false
  }
  self.u8_lower = 0x80
  self.u8_upper = 0xBF
  self.u8_cp = (self.u8_cp << 6) | (b & 0x3F)
  self.u8_seen += 1
  if self.u8_seen == self.u8_needed {
    push_char(out, self.u8_cp)
    self.u8_cp = 0
    self.u8_needed = 0
    self.u8_seen = 0
  }
  false
}

///|
/// The Encoding Standard's shared UTF-16 decoder handler.
fn LegacyDecoder::handle_utf16(
  self : LegacyDecoder,
  b : Int32,
  be : Bool,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.u16_lead_byte >= 0 || self.u16_lead_surrogate >= 0 {
      self.u16_lead_byte = -1
      self.u16_lead_surrogate = -1
      push_error(out)
      return false
    }
    return true
  }
  if self.u16_lead_byte < 0 {
    self.u16_lead_byte = b
    return false
  }
  let lead = self.u16_lead_byte
  self.u16_lead_byte = -1
  let unit = if be { (lead << 8) | b } else { (b << 8) | lead }
  if self.u16_lead_surrogate >= 0 {
    let ls = self.u16_lead_surrogate
    self.u16_lead_surrogate = -1
    if unit >= 0xDC00 && unit <= 0xDFFF {
      push_char(out, 0x10000 + ((ls - 0xD800) << 10) + (unit - 0xDC00))
      return false
    }
    // Prepend the code unit's bytes to the stream (the top of the restore
    // stack is processed first).
    let (b1, b2) = if be {
      (unit >> 8, unit & 0xFF)
    } else {
      (unit & 0xFF, unit >> 8)
    }
    self.restore(b2)
    self.restore(b1)
    push_error(out)
    return false
  }
  if unit >= 0xD800 && unit <= 0xDBFF {
    self.u16_lead_surrogate = unit
    return false
  }
  if unit >= 0xDC00 && unit <= 0xDFFF {
    push_error(out)
    return false
  }
  push_char(out, unit)
  false
}

///|
fn push_error(out : Buffer) -> Unit {
  push_char(out, 0xFFFD)
}

///|
fn LegacyDecoder::handle_gb18030(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.lead == 0 && self.second == 0 && self.third == 0 {
      return true
    }
    self.lead = 0
    self.second = 0
    self.third = 0
    push_error(out)
    return false
  }
  if self.third != 0 {
    if b < 0x30 || b > 0x39 {
      // Restore « second, third, byte ».
      self.restore(b)
      self.restore(self.third)
      self.restore(self.second)
      self.lead = 0
      self.second = 0
      self.third = 0
      push_error(out)
      return false
    }
    let pointer = (self.lead - 0x81) * (10 * 126 * 10) +
      (self.second - 0x30) * (10 * 126) +
      (self.third - 0x81) * 10 +
      b -
      0x30
    self.lead = 0
    self.second = 0
    self.third = 0
    let c = gb18030_ranges_code_point(pointer)
    if c < 0 {
      push_error(out)
    } else {
      push_char(out, c)
    }
    return false
  }
  if self.second != 0 {
    if b >= 0x81 && b <= 0xFE {
      self.third = b
      return false
    }
    // Restore « second, byte ».
    self.restore(b)
    self.restore(self.second)
    self.lead = 0
    self.second = 0
    push_error(out)
    return false
  }
  if self.lead != 0 {
    if b >= 0x30 && b <= 0x39 {
      self.second = b
      return false
    }
    let lead = self.lead
    self.lead = 0
    let offset = if b < 0x7F { 0x40 } else { 0x41 }
    let c = if (b >= 0x40 && b <= 0x7E) || (b >= 0x80 && b <= 0xFE) {
      index_gb18030.lookup((lead - 0x81) * 190 + (b - offset))
    } else {
      -1
    }
    if c >= 0 {
      push_char(out, c)
      return false
    }
    if b < 0x80 {
      self.restore(b)
    }
    push_error(out)
    return false
  }
  if b < 0x80 {
    push_char(out, b)
  } else if b == 0x80 {
    push_char(out, 0x20AC)
  } else if b <= 0xFE {
    self.lead = b
  } else {
    push_error(out)
  }
  false
}

///|
fn LegacyDecoder::handle_big5(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.lead == 0 {
      return true
    }
    self.lead = 0
    push_error(out)
    return false
  }
  if self.lead != 0 {
    let lead = self.lead
    self.lead = 0
    let offset = if b < 0x7F { 0x40 } else { 0x62 }
    if (b >= 0x40 && b <= 0x7E) || (b >= 0xA1 && b <= 0xFE) {
      let pointer = (lead - 0x81) * 157 + (b - offset)
      match pointer {
        1133 => {
          push_char(out, 0x00CA)
          push_char(out, 0x0304)
          return false
        }
        1135 => {
          push_char(out, 0x00CA)
          push_char(out, 0x030C)
          return false
        }
        1164 => {
          push_char(out, 0x00EA)
          push_char(out, 0x0304)
          return false
        }
        1166 => {
          push_char(out, 0x00EA)
          push_char(out, 0x030C)
          return false
        }
        _ => ()
      }
      let c = index_big5.lookup(pointer)
      if c >= 0 {
        push_char(out, c)
        return false
      }
    }
    if b < 0x80 {
      self.restore(b)
    }
    push_error(out)
    return false
  }
  if b < 0x80 {
    push_char(out, b)
  } else if b >= 0x81 && b <= 0xFE {
    self.lead = b
  } else {
    push_error(out)
  }
  false
}

///|
fn LegacyDecoder::handle_euc_jp(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.lead == 0 {
      return true
    }
    self.lead = 0
    push_error(out)
    return false
  }
  if self.lead == 0x8E && b >= 0xA1 && b <= 0xDF {
    self.lead = 0
    push_char(out, 0xFF61 - 0xA1 + b)
    return false
  }
  if self.lead == 0x8F && b >= 0xA1 && b <= 0xFE {
    self.jis0212 = true
    self.lead = b
    return false
  }
  if self.lead != 0 {
    let lead = self.lead
    self.lead = 0
    let c = if lead >= 0xA1 && lead <= 0xFE && b >= 0xA1 && b <= 0xFE {
      let pointer = (lead - 0xA1) * 94 + b - 0xA1
      if self.jis0212 {
        index_jis0212.lookup(pointer)
      } else {
        index_jis0208.lookup(pointer)
      }
    } else {
      -1
    }
    self.jis0212 = false
    if c >= 0 {
      push_char(out, c)
      return false
    }
    if b < 0x80 {
      self.restore(b)
    }
    push_error(out)
    return false
  }
  if b < 0x80 {
    push_char(out, b)
  } else if b == 0x8E || b == 0x8F || (b >= 0xA1 && b <= 0xFE) {
    self.lead = b
  } else {
    push_error(out)
  }
  false
}

///|
fn LegacyDecoder::handle_iso2022jp(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  match self.state {
    ISO2022_ASCII =>
      if b == 0x1B {
        self.state = ISO2022_ESCAPE_START
      } else if b == EOS {
        return true
      } else if b <= 0x7F && b != 0x0E && b != 0x0F {
        self.output = false
        push_char(out, b)
      } else {
        self.output = false
        push_error(out)
      }
    ISO2022_ROMAN =>
      if b == 0x1B {
        self.state = ISO2022_ESCAPE_START
      } else if b == EOS {
        return true
      } else if b == 0x5C {
        self.output = false
        push_char(out, 0x00A5)
      } else if b == 0x7E {
        self.output = false
        push_char(out, 0x203E)
      } else if b <= 0x7F && b != 0x0E && b != 0x0F {
        self.output = false
        push_char(out, b)
      } else {
        self.output = false
        push_error(out)
      }
    ISO2022_KATAKANA =>
      if b == 0x1B {
        self.state = ISO2022_ESCAPE_START
      } else if b == EOS {
        return true
      } else if b >= 0x21 && b <= 0x5F {
        self.output = false
        push_char(out, 0xFF61 - 0x21 + b)
      } else {
        self.output = false
        push_error(out)
      }
    ISO2022_LEAD =>
      if b == 0x1B {
        self.state = ISO2022_ESCAPE_START
      } else if b == EOS {
        return true
      } else if b >= 0x21 && b <= 0x7E {
        self.output = false
        self.lead = b
        self.state = ISO2022_TRAIL
      } else {
        self.output = false
        push_error(out)
      }
    ISO2022_TRAIL =>
      if b == 0x1B {
        self.state = ISO2022_ESCAPE_START
        push_error(out)
      } else if b >= 0x21 && b <= 0x7E {
        self.state = ISO2022_LEAD
        let c = index_jis0208.lookup((self.lead - 0x21) * 94 + b - 0x21)
        if c < 0 {
          push_error(out)
        } else {
          push_char(out, c)
        }
      } else {
        // Includes end-of-stream.
        self.state = ISO2022_LEAD
        push_error(out)
      }
    ISO2022_ESCAPE_START =>
      if b == 0x24 || b == 0x28 {
        self.lead = b
        self.state = ISO2022_ESCAPE
      } else {
        if b != EOS {
          self.restore(b)
        }
        self.output = false
        self.state = self.out_state
        push_error(out)
      }
    _ => {
      // Escape.
      let lead = self.lead
      self.lead = 0
      let state = if lead == 0x28 && b == 0x42 {
        ISO2022_ASCII
      } else if lead == 0x28 && b == 0x4A {
        ISO2022_ROMAN
      } else if lead == 0x28 && b == 0x49 {
        ISO2022_KATAKANA
      } else if lead == 0x24 && (b == 0x40 || b == 0x42) {
        ISO2022_LEAD
      } else {
        -1
      }
      if state >= 0 {
        self.state = state
        self.out_state = state
        let output = self.output
        self.output = true
        if output {
          push_error(out)
        }
      } else {
        // Restore « lead, byte » (or just lead at end-of-stream).
        if b != EOS {
          self.restore(b)
        }
        self.restore(lead)
        self.output = false
        self.state = self.out_state
        push_error(out)
      }
    }
  }
  false
}

///|
fn LegacyDecoder::handle_shift_jis(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.lead == 0 {
      return true
    }
    self.lead = 0
    push_error(out)
    return false
  }
  if self.lead != 0 {
    let lead = self.lead
    self.lead = 0
    let offset = if b < 0x7F { 0x40 } else { 0x41 }
    let lead_offset = if lead < 0xA0 { 0x81 } else { 0xC1 }
    if (b >= 0x40 && b <= 0x7E) || (b >= 0x80 && b <= 0xFC) {
      let pointer = (lead - lead_offset) * 188 + b - offset
      if pointer >= 8836 && pointer <= 10715 {
        push_char(out, 0xE000 - 8836 + pointer)
        return false
      }
      let c = index_jis0208.lookup(pointer)
      if c >= 0 {
        push_char(out, c)
        return false
      }
    }
    if b < 0x80 {
      self.restore(b)
    }
    push_error(out)
    return false
  }
  if b <= 0x80 {
    push_char(out, b)
  } else if b >= 0xA1 && b <= 0xDF {
    push_char(out, 0xFF61 - 0xA1 + b)
  } else if (b >= 0x81 && b <= 0x9F) || (b >= 0xE0 && b <= 0xFC) {
    self.lead = b
  } else {
    push_error(out)
  }
  false
}

///|
fn LegacyDecoder::handle_euc_kr(
  self : LegacyDecoder,
  b : Int32,
  out : Buffer,
) -> Bool {
  if b == EOS {
    if self.lead == 0 {
      return true
    }
    self.lead = 0
    push_error(out)
    return false
  }
  if self.lead != 0 {
    let lead = self.lead
    self.lead = 0
    if b >= 0x41 && b <= 0xFE {
      let c = index_euc_kr.lookup((lead - 0x81) * 190 + (b - 0x41))
      if c >= 0 {
        push_char(out, c)
        return false
      }
    }
    if b < 0x80 {
      self.restore(b)
    }
    push_error(out)
    return false
  }
  if b < 0x80 {
    push_char(out, b)
  } else if b >= 0x81 && b <= 0xFE {
    self.lead = b
  } else {
    push_error(out)
  }
  false
}
