///|
// Strategy: rg-file-read-ahead

///|
/// Only regular-file scans may read ahead. Streams, preprocessors, explicit
/// early exits and file-name summaries retain their original read budget.
fn ExecutionPlan::buffer_file_reads(self : ExecutionPlan) -> Bool {
  !self.output.quiet &&
  !self.output.quit_after_match &&
  self.search.max_count is None &&
  !self.search.stop_on_nonmatch &&
  (match self.mode {
    Search(Standard | Count | CountMatches | JSON) => true
    _ => false
  })
}

///|
let initial_file_read_bytes : Int32 = 65536

///|
let maximum_file_read_bytes : Int32 = 1048576

///|
/// Keep physical reads separate from the decoder's BOM and chunk requests.
/// A full initial block permits larger refills for this file; short reads do
/// not establish EOF. Large caller requests bypass an empty cache directly.
/// The worker owns and reuses storage only after the preceding search ends.
priv struct FileReadBuffer {
  inner : &@searcher.Reader
  buffer : FixedArray[Byte]
  mut pos : Int32
  mut end : Int32
  mut eof : Bool
  mut failure : Error?
  mut expanded : Bool
}

///|
fn FileReadBuffer::new(
  inner : &@searcher.Reader,
  buffer : FixedArray[Byte],
) -> FileReadBuffer {
  { inner, buffer, pos: 0, end: 0, eof: false, failure: None, expanded: false, }
}

///|
impl @searcher.Reader for FileReadBuffer with fn read(self, buf, start, len) {
  if len == 0 {
    return 0
  }
  if self.failure is Some(error) {
    raise error
  }
  let copied = len.min(self.end - self.pos)
  if copied > 0 {
    self.buffer.blit_to(buf, src_offset=self.pos, dst_offset=start, len=copied)
    self.pos += copied
  }
  if copied == len || self.eof {
    return copied
  }
  let remaining = len - copied
  let refill = remaining < self.buffer.length()
  let capacity = if self.expanded {
    self.buffer.length()
  } else {
    self.buffer.length().min(initial_file_read_bytes)
  }
  let count = try {
    if refill {
      self.inner.read(self.buffer, 0, capacity)
    } else {
      self.inner.read(buf, start + copied, remaining)
    }
  } catch {
    error => {
      self.failure = Some(error)
      if copied == 0 {
        raise error
      }
      // Previously read bytes precede a later read failure. Return them once
      // and report the retained error on the next request, without replay.
      return copied
    }
  }
  if count == 0 {
    self.eof = true
  }
  if count >= capacity {
    self.expanded = true
  }
  if refill {
    let taken = remaining.min(count)
    self.buffer.blit_to(buf, src_offset=0, dst_offset=start + copied, len=taken)
    self.pos = taken
    self.end = count
    return copied + taken
  }
  copied + count
}
