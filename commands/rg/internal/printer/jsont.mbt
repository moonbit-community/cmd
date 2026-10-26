///|
/// The JSON message types emitted by the JSON printer.
priv enum Message {
  Begin(path~ : String?)
  End(path~ : String?, binary_offset~ : Int64?, stats~ : Stats)
  Match(
    path~ : String?,
    buf~ : FixedArray[Byte],
    start~ : Int32,
    end~ : Int32,
    line_number~ : Int64?,
    absolute_offset~ : Int64,
    submatches~ : Array[SubMatch]
  )
  Context(
    path~ : String?,
    buf~ : FixedArray[Byte],
    start~ : Int32,
    end~ : Int32,
    line_number~ : Int64?,
    absolute_offset~ : Int64,
    submatches~ : Array[SubMatch]
  )
}

///|
/// A single submatch: `buf[m_start:m_end]` is the matched text and
/// `start`/`end` are its offsets relative to the reported lines.
priv struct SubMatch {
  buf : FixedArray[Byte]
  m_start : Int32
  m_end : Int32
  replacement : Bytes?
  start : Int32
  end : Int32
}

///|
fn Message::write_json(self : Message, w : JsonWriter) -> Unit {
  w.begin_object()
  match self {
    Begin(path~) => {
      w.key("type")
      w.write_escaped_string("begin")
      w.end_value()
      w.key("data")
      w.begin_object()
      write_path_field(w, path)
      w.end_object()
      w.end_value()
    }
    End(path~, binary_offset~, stats~) => {
      w.key("type")
      w.write_escaped_string("end")
      w.end_value()
      w.key("data")
      w.begin_object()
      write_path_field(w, path)
      w.key("binary_offset")
      match binary_offset {
        Some(n) => w.uint64(n.reinterpret_as_uint64())
        None => w.null()
      }
      w.end_value()
      w.key("stats")
      stats.write_json(w)
      w.end_value()
      w.end_object()
      w.end_value()
    }
    Match(
      path~,
      buf~,
      start~,
      end~,
      line_number~,
      absolute_offset~,
      submatches~
    ) => {
      w.key("type")
      w.write_escaped_string("match")
      w.end_value()
      w.key("data")
      write_lines_message(
        w, path, buf, start, end, line_number, absolute_offset, submatches,
      )
      w.end_value()
    }
    Context(
      path~,
      buf~,
      start~,
      end~,
      line_number~,
      absolute_offset~,
      submatches~
    ) => {
      w.key("type")
      w.write_escaped_string("context")
      w.end_value()
      w.key("data")
      write_lines_message(
        w, path, buf, start, end, line_number, absolute_offset, submatches,
      )
      w.end_value()
    }
  }
  w.end_object()
}

///|
fn write_path_field(w : JsonWriter, path : String?) -> Unit {
  w.key("path")
  match path {
    // A path that isn't valid UTF-8 is written as `{"bytes": ...}`.
    Some(p) if @osstr.has_escapes(p) => {
      let b = @osstr.encode(p).to_fixedarray()
      write_data(w, b, 0, b.length())
    }
    Some(p) => {
      w.begin_object()
      w.key("text")
      w.write_escaped_string(p)
      w.end_value()
      w.end_object()
    }
    None => w.null()
  }
  w.end_value()
}

///|
fn write_lines_message(
  w : JsonWriter,
  path : String?,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
  line_number : Int64?,
  absolute_offset : Int64,
  submatches : Array[SubMatch],
) -> Unit {
  w.begin_object()
  write_path_field(w, path)
  w.key("lines")
  write_data(w, buf, start, end)
  w.end_value()
  w.key("line_number")
  match line_number {
    Some(n) => w.uint64(n.reinterpret_as_uint64())
    None => w.null()
  }
  w.end_value()
  w.key("absolute_offset")
  w.uint64(absolute_offset.reinterpret_as_uint64())
  w.end_value()
  w.key("submatches")
  w.begin_array()
  for sm in submatches {
    w.element()
    w.begin_object()
    w.key("match")
    write_data(w, sm.buf, sm.m_start, sm.m_end)
    w.end_value()
    if sm.replacement is Some(r) {
      let tmp = r.to_fixedarray()
      w.key("replacement")
      write_data(w, tmp, 0, tmp.length())
      w.end_value()
    }
    w.key("start")
    w.uint64(sm.start.to_uint64())
    w.end_value()
    w.key("end")
    w.uint64(sm.end.to_uint64())
    w.end_value()
    w.end_object()
    w.end_value()
  }
  w.end_array()
  w.end_value()
  w.end_object()
}

///|
/// Writes arbitrary bytes as `{"text": ...}` if they are valid UTF-8, or
/// `{"bytes": <base64>}` otherwise.
fn write_data(
  w : JsonWriter,
  buf : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> Unit {
  w.begin_object()
  if is_valid_utf8(buf, start, end) {
    w.key("text")
    w.write_escaped_utf8(buf, start, end)
  } else {
    w.key("bytes")
    w.write_escaped_string(base64_standard(buf, start, end))
  }
  w.end_value()
  w.end_object()
}

///|
/// Returns true if `buf[start:end]` is valid UTF-8.
fn is_valid_utf8(buf : FixedArray[Byte], start : Int32, end : Int32) -> Bool {
  let mut i = start
  while i < end {
    let b = buf[i].to_int()
    if b < 0x80 {
      i += 1
      continue
    }
    let n = utf8_decode_lossy_len(buf, i, end)
    let need = if b >= 0xC2 && b <= 0xDF {
      2
    } else if b >= 0xE0 && b <= 0xEF {
      3
    } else if b >= 0xF0 && b <= 0xF4 {
      4
    } else {
      return false
    }
    if n != need {
      return false
    }
    i += n
  }
  true
}

///|
/// Standard base64 encoding (with padding) of `bytes[start:end]`.
fn base64_standard(
  bytes : FixedArray[Byte],
  start : Int32,
  end : Int32,
) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let out = StringBuilder()
  let push = (i : Int32) => {
    out.write_char(alphabet[i].to_int().unsafe_to_char())
  }
  let mut i = start
  while i + 3 <= end {
    let group24 = (bytes[i].to_int() << 16) |
      (bytes[i + 1].to_int() << 8) |
      bytes[i + 2].to_int()
    push((group24 >> 18) & 0x3F)
    push((group24 >> 12) & 0x3F)
    push((group24 >> 6) & 0x3F)
    push(group24 & 0x3F)
    i += 3
  }
  let rem = end - i
  if rem == 1 {
    let group8 = bytes[i].to_int()
    push((group8 >> 2) & 0x3F)
    push((group8 << 4) & 0x3F)
    out.write_string("==")
  } else if rem == 2 {
    let group16 = (bytes[i].to_int() << 8) | bytes[i + 1].to_int()
    push((group16 >> 10) & 0x3F)
    push((group16 >> 4) & 0x3F)
    push((group16 << 2) & 0x3F)
    out.write_char('=')
  }
  out.to_string()
}
