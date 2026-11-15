///|
pub fn labeled_address(offset : Int64, base : Int32, label : Int64?) -> String {
  match label {
    None => address(offset, base)
    Some(delta) => {
      let pseudo = "(" +
        address(
          if base == 0 {
            offset
          } else {
            offset + delta
          },
          if base == 0 {
            8
          } else {
            base
          },
        ) +
        ")"
      if base == 0 {
        pseudo
      } else {
        address(offset, base) + " " + pseudo
      }
    }
  }
}
