///|
fn random_key(seed : Bytes, key : Bytes) -> Bytes {
  let state = @crypto.MD5::new()
  state.update(seed)
  state.update(key)
  Bytes::from_array(state.finalize())
}

///|
fn prepared_key(key : BytesView, modifiers : Modifiers, seed : Bytes) -> Bytes {
  let effective = transformed_key(key, modifiers)
  if modifiers.mode != Random {
    return effective
  }
  let digest = random_key(seed, effective)
  let encoded = FixedArray::make(16 + effective.length(), b'\x00')
  for index in 0..<16 {
    encoded[index] = digest[index]
  }
  for index in 0..<effective.length() {
    encoded[index + 16] = effective[index]
  }
  encoded.unsafe_reinterpret_as_bytes()
}
