///|
fn default_modifiers(parsed : @cli.ParsedArgs) -> Modifiers raise CliError {
  let mut ordering_modes = 0
  for
    (name, mode) in [
      ("numeric-sort", @order.Numeric),
      ("general-numeric-sort", @order.GeneralNumeric),
      ("human-numeric-sort", @order.HumanNumeric),
      ("month-sort", @order.Month),
      ("random-sort", @order.Random),
      ("version-sort", @order.Version),
    ] {
    if parsed.contains(name) {
      ordering_modes = ordering_modes | @order.ordering_flag(mode)
    }
  }
  for value in parsed.values("sort") {
    let choices = [
      "general-numeric", "human-numeric", "month", "numeric", "random", "version",
    ]
    let selected = choices.filter(choice => choice.has_prefix(value))
    if selected.length() != 1 {
      let problem = if selected.is_empty() { "invalid" } else { "ambiguous" }
      let valid = choices.map(choice => "  - '\{choice}'\n").join("")
      raise @order.CliError(
        "sort: \{problem} argument '\{value}' for '--sort'\nValid arguments are:\n\{valid}Try 'sort --help' for more information.",
      )
    }
    let mode : @order.CompareMode = match selected[0] {
      "general-numeric" => GeneralNumeric
      "human-numeric" => HumanNumeric
      "month" => Month
      "numeric" => Numeric
      "random" => Random
      _ => Version
    }
    ordering_modes = ordering_modes | @order.ordering_flag(mode)
  }
  {
    ignore_leading_blanks: parsed.contains("ignore-leading-blanks"),
    dictionary_order: parsed.contains("dictionary-order"),
    fold_case: parsed.contains("ignore-case"),
    ignore_nonprinting: parsed.contains("ignore-nonprinting"),
    mode: @order.mode_from_flags(ordering_modes),
    ordering_modes,
    reverse: parsed.contains("reverse"),
  }
}
