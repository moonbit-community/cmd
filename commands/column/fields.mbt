///|
// Strategy: column-table-plans
priv struct TableField {
  data : BytesView
  width : Int32
}

///|
// Snapshot table payloads are already normalized to the ASCII C-byte display
// representation. Borrow them directly instead of decoding and re-encoding.
fn table_width(data : BytesView) -> Int32 {
  let mut width = 0
  let mut i = 0
  while i < data.length() {
    let byte = data[i]
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
  present : Bool
}

///|
#inline
fn FieldSeparator::next_field(
  self : FieldSeparator,
  data : BytesView,
  from : Int32,
) -> FieldSpan {
  let mut start = from
  for i = from; i < data.length(); i = i + 1 {
    let byte = data[i].to_int()
    if byte < 128 && self.members[byte] {
      if self.preserve_empty || i > start {
        return { start, end: i, present: true, }
      }
      start = i + 1
    }
  }
  if start <= data.length() && (self.preserve_empty || start < data.length()) {
    { start, end: data.length(), present: true, }
  } else {
    { start, end: data.length(), present: false, }
  }
}

///|
fn FieldSeparator::table_fields(
  self : FieldSeparator,
  data : BytesView,
) -> Array[TableField] {
  let fields : Array[TableField] = []
  for span = self.next_field(data, 0)
      span.present
      span = self.next_field(data, span.end + 1) {
    let field = data[span.start:span.end]
    fields.push({ data: field, width: table_width(field), })
  }
  fields
}

///|
// Cache construction shares the required width pass. If a row exceeds its
// budget, discard its partial plan and finish widths without scanning it again.
fn Snapshot::observe_table_fields(self : Snapshot, data : BytesView) -> Unit {
  let separator = self.separator
  let budget = (data.length() / field_plan_data_divisor).min(
    field_plan_byte_limit - self.field_plan_bytes,
  )
  let mut plan = if data.length() >= field_plan_min_row_bytes &&
    self.field_plans.length() < field_plan_row_limit &&
    budget >= field_plan_entry_bytes {
    Some(@buffer.Buffer(size_hint=budget.min(field_plan_initial_bytes)))
  } else {
    None
  }
  let mut column = 0
  for span = separator.next_field(data, 0)
      span.present
      span = separator.next_field(data, span.end + 1) {
    plan = self.observe_field(data, span.start, span.end, column, plan, budget)
    column += 1
  }
  if plan is Some(plan) {
    let bytes = plan.to_bytes()
    self.field_plans[self.records - 1] = bytes
    self.field_plan_bytes += bytes.length()
  }
}

///|
#inline
fn Snapshot::observe_field(
  self : Snapshot,
  data : BytesView,
  start : Int32,
  end : Int32,
  column : Int32,
  plan : @buffer.Buffer?,
  budget : Int32,
) -> @buffer.Buffer? {
  let width = table_width(data[start:end])
  while self.widths.length() <= column {
    self.widths.push(0)
  }
  self.widths[column] = self.widths[column].max(width)
  guard plan is Some(plan) && budget - plan.length() >= field_plan_entry_bytes else {
    return None
  }
  plan.write_int_le(start)
  plan.write_int_le(end)
  plan.write_int_le(width)
  Some(plan)
}

///|
fn plan_int(plan : Bytes, offset : Int32) -> Int32 {
  plan[offset].to_int() |
  (plan[offset + 1].to_int() << 8) |
  (plan[offset + 2].to_int() << 16) |
  (plan[offset + 3].to_int() << 24)
}

///|
fn fields_from_plan(data : BytesView, plan : Bytes) -> Array[TableField] {
  Array::makei(plan.length() / 12, i => {
    data: data[plan_int(plan, i * 12):plan_int(plan, i * 12 + 4)],
    width: plan_int(plan, i * 12 + 8),
  })
}
