///|
fn auth_arguments(
  args : ArrayView[String],
  specs : Array[@cli.OptionSpec],
) -> Array[String] {
  let output : Array[String] = []
  let mut literal = false
  let mut value_next = false
  for arg in args {
    if literal || value_next {
      output.push(arg)
      value_next = false
      continue
    }
    if arg == "--" {
      literal = true
    }
    if arg == "--auth-no-challenge" {
      output.push(arg + "=on")
      continue
    }
    output.push(arg)
    if arg.has_prefix("--") && !arg.contains("=") {
      value_next = specs.any(spec => spec.takes_value && arg == "--" + spec.name)
    } else if arg.has_prefix("-") && !arg.has_prefix("--") {
      let chars = arg.iter().to_array()
      for index = 1; index < chars.length(); index = index + 1 {
        if specs.any(spec => {
            spec.takes_value && spec.short == Some(chars[index])
          }) {
          value_next = index == chars.length() - 1
          break
        }
      }
    }
  }
  output
}
