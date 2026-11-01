///|
priv struct TailChunk {
  data : Bytes
  mut start : Int32
  mut breaks : Int64
}

///|
priv struct TailWindow {
  chunks : @deque.Deque[TailChunk]
  mut bytes : Int64
  mut breaks : Int64
}

///|
fn TailWindow::new() -> TailWindow {
  { chunks: @deque.Deque([]), bytes: 0L, breaks: 0L, }
}

///|
fn TailWindow::drop_front(self : TailWindow) -> Unit {
  let first = self.chunks[0]
  self.bytes -= (first.data.length() - first.start).to_int64()
  self.breaks -= first.breaks
  // Deque removal retains its vacated slot; release the backing bytes first.
  self.chunks[0] = { data: b"", start: 0, breaks: 0L, }
  ignore(self.chunks.pop_front())
}

///|
fn TailWindow::push(
  self : TailWindow,
  data : Bytes,
  count : Int64,
  bytes_mode : Bool,
  delimiter : Byte,
) -> Unit {
  guard !data.is_empty() else { return }
  let breaks = if bytes_mode {
    0L
  } else {
    count_newlines(data, delimiter~).to_int64()
  }
  self.chunks.push_back({ data, start: 0, breaks, })
  self.bytes += data.length().to_int64()
  self.breaks += breaks
  if bytes_mode {
    while self.bytes > count {
      let first = self.chunks[0]
      let excess = self.bytes - count
      let available = first.data.length() - first.start
      if excess >= available.to_int64() {
        self.drop_front()
      } else {
        first.start += excess.to_int()
        self.bytes -= excess
      }
    }
  } else {
    // An unfinished final record occupies one of the selected line slots.
    let allowed = if data[data.length() - 1] == delimiter {
      count
    } else {
      count - 1
    }
    while self.breaks > allowed {
      let first = self.chunks[0]
      let excess = self.breaks - allowed
      if first.breaks < excess {
        self.drop_front()
      } else {
        // Locate the cut from the side with fewer delimiter crossings. Small
        // suffix selections must not rescan most of every incoming chunk.
        let retained = first.breaks - excess + 1L
        let end = if excess <= retained {
          let mut remaining = excess
          let mut position = first.start
          while remaining > 0 {
            if first.data[position] == delimiter {
              remaining -= 1
            }
            position += 1
          }
          position
        } else {
          let mut remaining = retained
          let mut position = first.data.length()
          while remaining > 0 {
            position -= 1
            if first.data[position] == delimiter {
              remaining -= 1
            }
          }
          position + 1
        }
        if end == first.data.length() {
          self.drop_front()
        } else {
          self.bytes -= (end - first.start).to_int64()
          first.start = end
          first.breaks -= excess
          self.breaks -= excess
        }
      }
    }
  }
  if self.chunks.capacity() > 64 &&
    self.chunks.length() < self.chunks.capacity() / 4 {
    self.chunks.shrink_to_fit()
  }
}

///|
async fn TailWindow::write(self : TailWindow, writer : &@io.Writer) -> Unit {
  for chunk in self.chunks.iter() {
    writer.write(chunk.data[chunk.start:])
  }
}
