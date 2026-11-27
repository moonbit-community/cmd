///|
pub fn Separator::observe_fields(
  self : Separator,
  data : BytesView,
  widths : Array[Int32],
  budget : Int32?,
) -> Bytes? {
  let capacity = budget.unwrap_or(0)
  let mut plan = if capacity >= FIELD_PLAN_ENTRY_BYTES {
    Some(@buffer.Buffer(capacity=capacity.min(FIELD_PLAN_INITIAL_BYTES)))
  } else {
    None
  }
  let mut column = 0
  for span = self.next_field(data, 0)
      span.present
      span = self.next_field(data, span.next) {
    plan = observe_field(
      widths,
      data,
      span.start,
      span.end,
      column,
      plan,
      capacity,
      self.profile,
    )
    column += 1
  }
  plan.map(buffer => buffer.to_bytes())
}

///|
#inline
fn observe_field(
  widths : Array[Int32],
  data : BytesView,
  start : Int32,
  end : Int32,
  column : Int32,
  plan : @buffer.Buffer?,
  budget : Int32,
  profile : @textwidth.Profile,
) -> @buffer.Buffer? {
  let width = table_width(data[start:end], profile)
  while widths.length() <= column {
    widths.push(0)
  }
  widths[column] = widths[column].max(width)
  guard plan is Some(plan) && budget - plan.length() >= FIELD_PLAN_ENTRY_BYTES else {
    return None
  }
  plan.write_int_le(start)
  plan.write_int_le(end)
  plan.write_int_le(width)
  Some(plan)
}
