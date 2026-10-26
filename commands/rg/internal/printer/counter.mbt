///|
/// A writer that counts the number of bytes that have been successfully
/// written.
priv struct CounterWriter {
  wtr : &@termcolor.WriteColor
  // Whether `wtr` supports color. When it doesn't, setting and resetting
  // colors are no-ops, so they're skipped (they happen several times per
  // printed line).
  color : Bool
  mut count : Int64
  mut total_count : Int64
}

///|
fn CounterWriter::new(wtr : &@termcolor.WriteColor) -> CounterWriter {
  { wtr, color: wtr.supports_color(), count: 0, total_count: 0, }
}

///|
/// Returns the total number of bytes written since construction or the
/// last time `reset_count` was called.
fn CounterWriter::count(self : CounterWriter) -> Int64 {
  self.count
}

///|
/// Returns the total number of bytes written since construction.
fn CounterWriter::total_count(self : CounterWriter) -> Int64 {
  self.total_count + self.count
}

///|
/// Resets the number of bytes written to `0`.
fn CounterWriter::reset_count(self : CounterWriter) -> Unit {
  self.total_count += self.count
  self.count = 0
}

///|
fn CounterWriter::get_mut(self : CounterWriter) -> &@termcolor.WriteColor {
  self.wtr
}

///|
impl @termcolor.Write for CounterWriter with fn write_slice(
  self,
  buf,
  start,
  end,
) {
  @termcolor.Write::write_slice(self.wtr, buf, start, end)
  self.count += (end - start).to_int64()
}

///|
impl @termcolor.Write for CounterWriter with fn write_bytes(self, bytes) {
  @termcolor.Write::write_bytes(self.wtr, bytes)
  self.count += bytes.length().to_int64()
}

///|
impl @termcolor.Write for CounterWriter with fn flush(self) {
  @termcolor.Write::flush(self.wtr)
}

///|
impl @termcolor.WriteColor for CounterWriter with fn supports_color(self) {
  self.color
}

///|
impl @termcolor.WriteColor for CounterWriter with fn supports_hyperlinks(self) {
  self.wtr.supports_hyperlinks()
}

///|
impl @termcolor.WriteColor for CounterWriter with fn set_color(self, spec) {
  if self.color {
    self.wtr.set_color(spec)
  }
}

///|
impl @termcolor.WriteColor for CounterWriter with fn set_hyperlink(self, link) {
  self.wtr.set_hyperlink(link)
}

///|
impl @termcolor.WriteColor for CounterWriter with fn reset(self) {
  if self.color {
    self.wtr.reset()
  }
}

///|
impl @termcolor.WriteColor for CounterWriter with fn is_synchronous(self) {
  self.wtr.is_synchronous()
}

///|
extend CounterWriter with @termcolor.Write::{write_slice, write_bytes}

///|
extend CounterWriter with @termcolor.WriteColor::{
  supports_color,
  set_color,
  reset,
}
