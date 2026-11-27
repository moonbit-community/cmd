///|
fn render_help(metadata : Metadata) -> String raise {
  render_help_text(metadata, metadata.help)
}

///|
fn render_help_text(metadata : Metadata, text : String) -> String raise {
  let mut help = text
  for option in metadata.options {
    if option.help_lines is Some(lines) {
      for index, line in lines {
        let marker = "{{help:" + option.name + ":" + index.to_string() + "}}"
        help = help.replace_all(old=marker, new=line)
      }
    }
  }
  guard !help.contains("{{help:") else {
    fail("missing option help text: " + metadata.command)
  }
  help
}

///|
fn validate_help(metadata : Metadata) -> Unit raise {
  let texts = [
    metadata.help,
    ..metadata.help_variants.unwrap_or([]).map(variant => variant.text),
  ]
  for option in metadata.options {
    for index, _ in option.help_lines.unwrap_or([]) {
      let marker = "{{help:" + option.name + ":" + index.to_string() + "}}"
      guard texts.any(text => text.contains(marker)) else {
        fail("unused option help line: " + metadata.command + ":" + marker)
      }
    }
  }
  let variants : Set[(String, Bool)] = Set([])
  for variant in metadata.help_variants.unwrap_or([]) {
    guard !variants.contains((variant.command, variant.long)) else {
      fail("duplicate help variant")
    }
    variants.insert((variant.command, variant.long))
    ignore(render_help_text(metadata, variant.text))
  }
}
