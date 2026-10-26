///|
/// Validates a `--colors` spec using the printer's parser, so that invalid
/// specs are reported while parsing flags (as ripgrep does).
fn validate_color_spec(spec : String) -> Unit raise RgError {
  ignore(
    @printer.UserColorSpec::parse(spec) catch {
      e => raise RgError(e.to_string())
    },
  )
}

///|
/// Validates a `--hyperlink-format` value.
fn validate_hyperlink_format(s : String) -> Unit raise RgError {
  ignore(
    @printer.HyperlinkFormat::parse(s) catch {
      e => raise RgError(e.to_string())
    },
  )
}
