///|
pub fn grid_shape(
  records : Int64,
  longest : Int32,
  width : Int32,
) -> (Int64, Int64, Int64) {
  let stride = (longest.to_int64() / 8 + 1) * 8
  let columns = if longest >= width {
    1L
  } else {
    (width.to_int64() / stride).max(1).min(records)
  }
  let rows = records / columns + (if records % columns == 0 { 0L } else { 1L })
  (stride, columns, rows)
}
