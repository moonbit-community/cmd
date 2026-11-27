///|
// Strategy: column-table-plans
pub struct Field {
  priv data : BytesView
  priv width : Int32
}

///|
// Measure the normalized snapshot directly so field offsets remain byte offsets.
fn table_width(data : BytesView, profile : @textwidth.Profile) -> Int32 {
  let mut width = 0
  let mut i = 0
  while i < data.length() {
    let byte = data[i]
    if profile == Utf8 && byte >= 128 {
      let (ch, len) = profile.next(data, i)
      width += @textwidth.cells(ch, fallback=0)
      i += len
      continue
    }
    i += 1
    if byte >= b' ' && byte <= b'~' {
      width += 1
    } else if i < data.length() && data[i] == b'[' {
      let mut end = i + 1
      while end < data.length() && data[end] != b'm' {
        end += 1
      }
      if end < data.length() {
        i = end + 1
      }
    }
  }
  width
}

///|
#valtype
priv struct FieldSpan {
  start : Int32
  end : Int32
  next : Int32
  present : Bool
}

///|
#inline
fn Separator::next_field(
  self : Separator,
  data : BytesView,
  from : Int32,
) -> FieldSpan {
  let mut start = from
  for i = from; i < data.length(); {
    let byte = data[i].to_int()
    let (separator, len) = if byte < 128 || self.wide.is_empty() {
      (byte < 128 && self.members[byte], 1)
    } else {
      let (ch, len) = self.profile.next(data, i)
      (ch is Some(c) && self.wide.contains(c), len)
    }
    if separator {
      if self.preserve_empty || i > start {
        return { start, end: i, next: i + len, present: true, }
      }
      start = i + len
    }
    continue i + len
  }
  if start <= data.length() && (self.preserve_empty || start < data.length()) {
    { start, end: data.length(), next: data.length() + 1, present: true, }
  } else {
    { start, end: data.length(), next: data.length() + 1, present: false, }
  }
}

///|
pub fn Separator::table_fields(
  self : Separator,
  data : BytesView,
) -> Array[Field] {
  let fields : Array[Field] = []
  for span = self.next_field(data, 0)
      span.present
      span = self.next_field(data, span.next) {
    let field = data[span.start:span.end]
    fields.push({ data: field, width: table_width(field, self.profile), })
  }
  fields
}

///|
fn plan_int(plan : Bytes, offset : Int32) -> Int32 {
  plan[offset].to_int() |
  (plan[offset + 1].to_int() << 8) |
  (plan[offset + 2].to_int() << 16) |
  (plan[offset + 3].to_int() << 24)
}

///|
pub fn fields_from_plan(data : BytesView, plan : Bytes) -> Array[Field] {
  Array::makei(plan.length() / 12, i => {
    data: data[plan_int(plan, i * 12):plan_int(plan, i * 12 + 4)],
    width: plan_int(plan, i * 12 + 8),
  })
}
