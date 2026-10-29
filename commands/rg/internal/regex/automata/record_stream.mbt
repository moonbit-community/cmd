///|
priv struct BooleanRecordStream {
  plan : WideBoolean
  term : Byte
  required : Prefilter?
  mut state : Int32
  mut pending : Bool
  mut accelerating : Bool
}

///|
// The complete transition table is resolved before input can be discarded.
// Chunk boundaries never take an EOF transition; only delimiters and finish do.
pub fn RecordBoolean::stream_counter(
  self : RecordBoolean,
  term : Byte,
  pre? : Prefilter,
) -> (FixedArray[Byte], Int32, Int32, Bool) -> Int64 {
  let plan = self.wide_plan()
  let cursor = BooleanRecordStream::{
    plan,
    term,
    required: pre,
    state: plan.start,
    pending: false,
    accelerating: true,
  }
  (hay, start, end, finish) => cursor.feed(hay, start, end, finish)
}

///|
fn BooleanRecordStream::scan(
  self : BooleanRecordStream,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  let plan = self.plan
  let table = plan.transitions
  let mut state = self.state
  let mut at = start
  while end - at >= 4 && state != plan.accept {
    let previous = state
    state = wide_step4(table, hay, state, at)
    at += 4
    if self.accelerating &&
      state == previous &&
      end - at >= boolean_probe_window_bytes {
      // A truncated chunk prefix is not evidence of record exit density.
      let probe = plan.probe_exit(
        hay,
        at,
        end,
        state,
        at - start >= boolean_probe_window_bytes,
      )
      at = probe.offset
      self.accelerating = probe.accelerating
    }
  }
  while at < end && state != plan.accept {
    state = table[state + hay[at].to_int()]
    at += 1
  }
  self.state = state
}

///|
fn BooleanRecordStream::feed(
  self : BooleanRecordStream,
  hay : FixedArray[Byte],
  start : Int32,
  end : Int32,
  finish : Bool,
) -> Int64 {
  let mut count = 0L
  let mut at = start
  while at < end {
    if !self.pending && self.required is Some(filter) {
      let last = @memchr.memrchr(self.term, hay, at, end)
      if last >= at {
        let candidate = filter.find_span(hay, at, last + 1)
        if candidate == NO_SPAN {
          at = last + 1
          continue
        }
        let previous = @memchr.memrchr(
          self.term,
          hay,
          at,
          span_start(candidate),
        )
        if previous >= 0 {
          at = previous + 1
        }
      }
    }
    let newline = @memchr.memchr(self.term, hay, at, end)
    let limit = if newline < 0 { end } else { newline }
    if limit > at {
      self.pending = true
      self.scan(hay, at, limit)
    }
    if newline >= 0 {
      count += self.end_record()
      at = limit + 1
    } else {
      at = end
    }
  }
  if finish {
    count += self.end_record()
  }
  count
}

///|
fn BooleanRecordStream::end_record(self : BooleanRecordStream) -> Int64 {
  let matched = self.pending &&
    (self.state == self.plan.accept || self.plan.eof[self.state / 256])
  self.state = self.plan.start
  self.pending = false
  self.accelerating = true
  if matched {
    1L
  } else {
    0L
  }
}
