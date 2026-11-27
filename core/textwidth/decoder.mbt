///|
pub struct Decoder {
  priv profile : Profile
  priv mut carry : Bytes
}

///|
pub fn Decoder::Decoder(profile : Profile) -> Decoder {
  { profile, carry: b"", }
}

///|
/// Raw views are valid only during the callback. Each malformed byte is
/// reported separately. A partial scalar retains at most three bytes.
pub fn Decoder::feed(
  self : Decoder,
  data : BytesView,
  consume : (Char?, BytesView) -> Unit,
  eof~ : Bool = false,
) -> Unit {
  let mut offset = 0
  if !self.carry.is_empty() {
    let old = self.carry.length()
    let prefix = data.length().min(3)
    let joined = self.carry + data[:prefix].to_owned()
    self.carry = b""
    let mut i = 0
    while i < old {
      let (ch, len) = self.profile.next(joined[:], i, eof~)
      if len == 0 {
        self.carry = joined[i:].to_owned()
        return
      }
      consume(ch, joined[i:i + len])
      i += len
    }
    offset = i - old
  }
  while offset < data.length() {
    let (ch, len) = self.profile.next(data, offset, eof~)
    if len == 0 {
      self.carry = data[offset:].to_owned()
      return
    }
    consume(ch, data[offset:offset + len])
    offset += len
  }
}
