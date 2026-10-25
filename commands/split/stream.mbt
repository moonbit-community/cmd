///|
async fn record_segments(
  reader : &@io.Reader,
  consume : async (BytesView, Bool) -> Unit,
) -> Unit {
  while reader.read_some(max_len=65536) is Some(bytes) {
    let mut start = 0
    for index in 0..<bytes.length() {
      if bytes[index] == b'\n' {
        consume(bytes[start:index + 1], true)
        start = index + 1
      }
    }
    if start < bytes.length() {
      consume(bytes[start:], false)
    }
  }
}

///|
async fn copy_count(
  reader : &@io.Reader,
  count : Int64,
  consume : async (BytesView) -> Unit,
) -> Unit {
  if count == 0 {
    return
  }
  let buffer = FixedArray::make(65536, b'\x00')
  let mut remaining = count
  while remaining > 0 {
    let limit = if remaining < 65536L { remaining.to_int() } else { 65536 }
    let read = reader.read(buffer, max_len=limit)
    if read == 0 {
      break
    }
    let bytes = Bytes::from_array(buffer[:read])
    consume(bytes[:])
    remaining -= read.to_int64()
  }
}

///|
async fn split_bytes(
  reader : &@io.Reader,
  outputs : Outputs,
  size : Int64,
) -> Unit {
  let piece : Ref[Piece?] = Ref(None)
  let mut remaining = size
  while reader.read_some(max_len=65536) is Some(bytes) {
    let mut start = 0
    while start < bytes.length() {
      let available = (bytes.length() - start).to_int64()
      let take = if remaining < available {
        remaining.to_int()
      } else {
        available.to_int()
      }
      write_piece(outputs, piece, bytes[start:start + take])
      start += take
      remaining -= take.to_int64()
      if remaining == 0 {
        finish_piece(outputs, piece, true)
        remaining = size
      }
    }
  }
  finish_piece(outputs, piece, true)
}

///|
async fn split_lines(
  reader : &@io.Reader,
  outputs : Outputs,
  size : Int64,
) -> Unit {
  let piece : Ref[Piece?] = Ref(None)
  let mut records = 0L
  record_segments(reader, async fn(bytes, end_record) {
    write_piece(outputs, piece, bytes)
    if end_record {
      records += 1
      if records == size {
        finish_piece(outputs, piece, true)
        records = 0
      }
    }
  })
  finish_piece(outputs, piece, true)
}

///|
fn partition_end(size : Int64, count : Int64, index : Int64) -> Int64 {
  let used = index + 1
  let remainder = size % count
  let extra = if used < remainder { used } else { remainder }
  size / count * used + extra
}

///|
fn partition_index(size : Int64, count : Int64, position : Int64) -> Int64 {
  if position >= size {
    return count - 1
  }
  let width = size / count
  let remainder = size % count
  if remainder > 0 {
    let first = (width + 1) * remainder
    if position < first {
      return position / (width + 1)
    }
    return remainder + (position - first) / width
  }
  position / width
}

///|
priv suberror ChunkDone {
  ChunkDone
}

///|
async fn split_chunks(
  reader : &@io.Reader,
  outputs : Outputs,
  size : Int64,
  count : Int64,
  selected : Int64,
  lines : Bool,
) -> Unit {
  let piece : Ref[Piece?] = Ref(None)
  if size == 0 && (outputs.names.options.elide || selected != 0) {
    return
  }
  if !lines {
    if selected != 0 {
      let start = if selected == 1 {
        0L
      } else {
        partition_end(size, count, selected - 2)
      }
      copy_count(reader, start, fn(_) { () })
      copy_count(reader, partition_end(size, count, selected - 1) - start, async fn(
        bytes,
      ) {
        @stdio.stdout.write(bytes)
      })
      return
    }
    let limit = if outputs.names.options.elide && count > size {
      size
    } else {
      count
    }
    let mut start = 0L
    for index = 0L; index < limit; index = index + 1 {
      let end = partition_end(size, count, index)
      copy_count(reader, end - start, async fn(bytes) {
        write_piece(outputs, piece, bytes)
      })
      finish_piece(outputs, piece, outputs.names.options.elide)
      start = end
    }
    return
  }
  let mut index = 0L
  let mut position = 0L
  let mut record_start = 0L
  record_segments(reader, async fn(bytes, end_record) {
    let target = partition_index(size, count, record_start)
    if selected != 0 {
      if target + 1 > selected {
        raise ChunkDone
      }
      index = target
    } else if outputs.names.options.elide && target > index {
      finish_piece(outputs, piece, true)
      index = target
    } else {
      while index < target {
        finish_piece(outputs, piece, false)
        index += 1
      }
    }
    if selected == 0 {
      write_piece(outputs, piece, bytes)
    } else if selected == index + 1 {
      @stdio.stdout.write(bytes)
    }
    position += bytes.length().to_int64()
    if end_record {
      record_start = position
    }
  }) catch {
    ChunkDone => ()
    error => raise error
  }
  if selected == 0 {
    if outputs.names.options.elide {
      finish_piece(outputs, piece, true)
    } else {
      while index < count {
        finish_piece(outputs, piece, false)
        index += 1
      }
    }
  }
}

///|
async fn split_round_robin(
  reader : &@io.Reader,
  outputs : Outputs,
  count : Int64,
  selected : Int64,
) -> Unit {
  let pieces : Map[Int64, Piece] = Map([])
  let mut index = 0L
  record_segments(reader, async fn(bytes, end_record) {
    if selected == 0 {
      let piece = match pieces.get(index) {
        Some(piece) => piece
        None => {
          let piece = outputs.open()
          pieces[index] = piece
          piece
        }
      }
      piece.write(bytes)
      if end_record {
        piece.suspend()
      }
    } else if selected == index + 1 {
      @stdio.stdout.write(bytes)
    }
    if end_record {
      index = if index + 1 == count { 0L } else { index + 1 }
    }
  })
  if selected != 0 {
    return
  }
  if outputs.names.options.elide {
    for piece in pieces.values() {
      outputs.finish(piece)
    }
  } else {
    for index = 0L; index < count; index = index + 1 {
      let piece = match pieces.get(index) {
        Some(piece) => piece
        None => outputs.open()
      }
      outputs.finish(piece)
    }
  }
}

///|
async fn emit_record(
  spool : @fs.File,
  length : Int64,
  outputs : Outputs,
  piece : Ref[Piece?],
) -> Unit {
  let mut position = 0L
  while position < length {
    let amount = if length - position < 65536L {
      (length - position).to_int()
    } else {
      65536
    }
    let bytes = spool.read_exactly_at(amount, position~)
    write_piece(outputs, piece, bytes[:])
    position += amount.to_int64()
  }
}

///|
async fn split_line_bytes(
  reader : &@io.Reader,
  outputs : Outputs,
  size : Int64,
  spool : @fs.File,
) -> Unit {
  let piece : Ref[Piece?] = Ref(None)
  let mut pending = 0L
  let mut written = 0L
  let mut split_line = false
  let append = async fn(bytes : BytesView) {
    if !bytes.is_empty() {
      if written == 0 {
        finish_piece(outputs, piece, true)
      }
      write_piece(outputs, piece, bytes)
      written += bytes.length().to_int64()
    }
  }
  let append_pending = async fn() {
    if pending > 0 {
      if written == 0 {
        finish_piece(outputs, piece, true)
      }
      emit_record(spool, pending, outputs, piece)
      written += pending
      pending = 0
    }
  }
  while reader.read_some(max_len=65536) is Some(bytes) {
    let mut start = 0
    while start < bytes.length() {
      let left = bytes.length() - start
      let boundary = size - written - pending <= left.to_int64()
      let mut rest = if boundary {
        (size - written - pending).to_int()
      } else {
        left
      }
      let mut line_end : Int32? = None
      for index in start..<(start + rest) {
        if bytes[index] == b'\n' {
          line_end = Some(index)
        }
      }
      if pending > 0 && (line_end is Some(_) || written == 0) {
        append_pending()
      }
      if line_end is Some(end) {
        split_line = true
        let amount = end - start + 1
        append(bytes[start:end + 1])
        start = end + 1
        if boundary {
          rest -= amount
        }
      }
      if start < bytes.length() && !split_line {
        let amount = if boundary { rest } else { bytes.length() - start }
        append(bytes[start:start + amount])
        start += amount
        if boundary {
          rest -= amount
        }
      }
      if (boundary && rest > 0) || (!boundary && start < bytes.length()) {
        let amount = if boundary { rest } else { bytes.length() - start }
        spool.write_at(bytes[start:start + amount], position=pending)
        pending += amount.to_int64()
        start += amount
      }
      if boundary {
        written = 0
        split_line = false
      }
    }
  }
  append_pending()
  finish_piece(outputs, piece, true)
}
