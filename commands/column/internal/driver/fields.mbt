///|
// Cache construction shares the required width pass and preserves its byte budget.
fn Snapshot::observe_table_fields(self : Snapshot, data : BytesView) -> Unit {
  let budget = (data.length() / FIELD_PLAN_DATA_DIVISOR).min(
    FIELD_PLAN_BYTE_LIMIT - self.field_plan_bytes,
  )
  let eligible = data.length() >= FIELD_PLAN_MIN_ROW_BYTES &&
    self.field_plans.length() < FIELD_PLAN_ROW_LIMIT
  if self.separator.observe_fields(
      data,
      self.widths,
      if eligible {
        Some(budget)
      } else {
        None
      },
    )
    is Some(bytes) {
    self.field_plans[self.records - 1] = bytes
    self.field_plan_bytes += bytes.length()
  }
}
