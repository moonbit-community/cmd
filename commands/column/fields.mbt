///|
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
fn FieldSeparator::table_fields(
  self : FieldSeparator,
  data : BytesView,
) -> Array[TableField] {
  let fields : Array[TableField] = []
  let mut start = 0
  for i in 0..<data.length() {
    let byte = data[i].to_int()
    if byte < 128 && self.members[byte] {
      if self.preserve_empty || i > start {
        let field = data[start:i]
        fields.push({ data: field, width: table_width(field), })
      }
      start = i + 1
    }
  }
  if self.preserve_empty || start < data.length() {
    let field = data[start:]
    fields.push({ data: field, width: table_width(field), })
  }
  fields
}

///|
// Cache construction shares the required width pass. If a row exceeds its
// budget, discard its partial plan and finish widths without scanning it again.
fn Snapshot::observe_table_fields(self : Snapshot, data : BytesView) -> Unit {
  let separator = self.separator
  let budget = (data.length() / 8).min(65536 - self.field_plan_bytes)
  let mut plan = if data.length() >= 1024 &&
    self.field_plans.length() < 128 &&
    budget >= 12 {
    Some(@buffer.Buffer(size_hint=budget.min(1024)))
  } else {
    None
  }
  let mut start = 0
  let mut column = 0
  for i in 0..<data.length() {
    let byte = data[i].to_int()
    if byte < 128 && separator.members[byte] {
      if separator.preserve_empty || i > start {
        plan = self.observe_field(data, start, i, column, plan, budget)
        column += 1
      }
      start = i + 1
    }
  }
  if separator.preserve_empty || start < data.length() {
    plan = self.observe_field(data, start, data.length(), column, plan, budget)
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
  guard plan is Some(plan) && budget - plan.length() >= 12 else { return None }
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
