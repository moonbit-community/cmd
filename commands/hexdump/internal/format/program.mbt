///|
pub fn finish_program(entries : Array[Entry]) -> Program raise FormatError {
  let mut block_size = 0
  let mut final_unit : UnitSpec? = None
  for entry in entries {
    match entry {
      Builtin(mode) => {
        if block_size < 16 {
          block_size = 16
        }
        let format = compile_format(
          @utf8.encode(
            if mode == "canonical" {
              "\"%08.8_Ax\\n\""
            } else {
              "\"%07.7_Ax\\n\""
            },
          )[:],
          false,
        )
        final_unit = format.units.get(0)
      }
      Custom(format) => {
        if block_size < format.count {
          block_size = format.count
        }
        for unit in format.units {
          if unit.final_address {
            final_unit = Some(unit)
          }
        }
      }
    }
  }
  for entry in entries {
    if entry is Custom(format) &&
      format.count < block_size &&
      format.units.last() is Some(unit) &&
      !unit.explicit_reps &&
      unit.count > 0 {
      unit.reps += (block_size - format.count) / unit.count
    }
  }
  { entries, block_size, final_unit, }
}
