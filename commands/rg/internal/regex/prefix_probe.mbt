///|
// A byte-set prefix is necessary even when its frequency makes it unsuitable
// as the main matcher. None means no such proof; Some(-1) proves absence.
pub fn Regex::byte_prefix_start(
  self : Regex,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Int32? {
  match self.pre {
    Some(@automata.Prefilter::ByteSet(set)) =>
      if start < end && set.contains(hay[start]) {
        Some(start)
      } else {
        Some(set.find(hay, start, end))
      }
    _ => None
  }
}
