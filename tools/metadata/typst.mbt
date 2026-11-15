///|
fn typst_arguments(options : Array[OptionMetadata]) -> String {
  let out = StringBuilder()
  for option in options {
    guard option.typst is Some(spec) else { continue }
    out.write_string(
      "\n///|\nfn argument_" + option.name.replace_all(old="-", new="_") + "(",
    )
    for dynamic in spec.dynamic {
      let type_ = match dynamic {
        "validate" => "(String) -> Unit raise CliError"
        "delimiter" => "Char"
        "possible" => "Array[String]"
        _ => abort("invalid typst adapter parameter")
      }
      out.write_string(dynamic + "~ : " + type_ + ", ")
    }
    out.write_string(
      ") -> ArgSpec {\n  " +
      spec.builder +
      "(" +
      quoted(option.parser_name.unwrap_or(option.name)),
    )
    if spec.variable is Some(variable) {
      out.write_string(", " + quoted(variable))
    }
    if spec.missing is Some(missing) {
      out.write_string(", " + quoted(missing))
    }
    if option.short is Some(short) {
      out.write_string(", short='" + short + "'")
    }
    if spec.environment is Some(env) {
      out.write_string(", env=" + quoted(env))
    }
    if spec.delimiter is Some(delimiter) {
      out.write_string(", delimiter='" + delimiter + "'")
    }
    if !spec.choices.is_empty() {
      out.write_string(
        ", possible=[" + spec.choices.map(quoted).join(", ") + "]",
      )
    }
    if spec.hidden {
      out.write_string(", hidden=true")
    }
    if spec.empty == "Pass" {
      out.write_string(", empty=Pass")
    }
    if option.repeatable {
      out.write_string(", multiple=true")
    }
    for dynamic in spec.dynamic {
      out.write_string(", " + dynamic + "~")
    }
    out.write_string(", help=" + quoted(spec.help_text) + ")\n}\n")
  }
  out.to_string()
}
