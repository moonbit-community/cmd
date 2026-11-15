///|
fn Snapshot::table_row(
  self : Snapshot,
  data : BytesView,
  separator : Bytes,
  plan : Bytes?,
) -> @layout.Row {
  let fields = match plan {
    Some(plan) => @layout.fields_from_plan(data, plan)
    None => self.separator.table_fields(data)
  }
  @layout.Row::new(fields, self.widths, separator)
}
