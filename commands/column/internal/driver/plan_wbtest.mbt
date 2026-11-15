///|
priv struct ObservedField {
  data : BytesView
  width : Int32
}

///|
// Decode the stored little-endian plan independently of the layout decoder.
fn observed_plan(data : BytesView, plan : Bytes) -> Array[ObservedField] {
  let values = Array::makei(plan.length() / 4, index => {
    let mut value = 0
    for offset in 0..<4 {
      value += plan[index * 4 + offset].to_int() << (offset * 8)
    }
    value
  })
  Array::makei(values.length() / 3, index => {
    data: data[values[index * 3]:values[index * 3 + 1]],
    width: values[index * 3 + 2],
  })
}
