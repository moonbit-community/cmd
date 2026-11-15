///|
// Strategy: diff-byte-pipeline
priv struct PatchOutput {
  bytes : @buffer.Buffer
}

///|
fn PatchOutput::new() -> PatchOutput {
  { bytes: @buffer.Buffer(), }
}

///|
// Headers use the existing byte-preserving argument representation. Source
// records append their original bytes directly without a text round trip.
fn PatchOutput::write_string(self : PatchOutput, text : String) -> Unit {
  self.bytes.write_bytes(@bytere.bytes(text))
}
