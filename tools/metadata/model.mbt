///|
#derive(FromJson)
priv struct OptionMetadata {
  name : String
  parser_name : String?
  parser_long : String?
  parser_action : String?
  aliases : Array[String]
  value : String
  description : String
  help_lines : Array[String]?
  default_value : String?
  default_binding : DefaultBinding?
  support_note : String?
  short : String?
  repeatable : Bool
  allow_attached : Bool
  allow_hyphen_values : Bool?
  rg : RgMetadata?
  typst : TypstMetadata?
}

///|
#derive(FromJson)
priv struct DefaultBinding {
  name : String
  type_ : String
  scale : Int32?
  variant : String?
}

///|
#derive(FromJson)
priv struct HelpVariant {
  command : String
  long : Bool
  text : String
}

///|
#derive(FromJson)
priv struct TypstMetadata {
  builder : String
  variable : String?
  missing : String?
  environment : String?
  delimiter : String?
  choices : Array[String]
  hidden : Bool
  empty : String
  help_text : String
  dynamic : Array[String]
}

///|
#derive(FromJson)
priv struct RgMetadata {
  negated : String?
  variable : String?
  category : String
  long_help : String
  choices : Array[String]
  completion : String
}

///|
#derive(FromJson)
priv struct Table {
  kind : String?
  function_name : String
  import_alias : String
  options : Array[String]
}

///|
#derive(FromJson)
priv struct Metadata {
  schema : Int32
  command : String
  help : String
  catalog_options : Array[String]
  options : Array[OptionMetadata]
  readme_options : Array[String]?
  tables : Array[Table]
  help_variants : Array[HelpVariant]?
  adapter_match : Bool?
}

///|
fn validate(metadata : Metadata) -> Unit raise {
  guard metadata.schema == 1 &&
    !metadata.command.is_empty() &&
    metadata.help.has_prefix("Usage: " + metadata.command) &&
    metadata.help.has_suffix("\n") else {
    fail("invalid command metadata")
  }
  let names : Set[String] = Set([])
  for option in metadata.options {
    guard !option.name.is_empty() &&
      !names.contains(option.name) &&
      !option.aliases.is_empty() &&
      ["none", "required", "optional", "adapter"].contains(option.value) &&
      !option.description.is_empty() else {
      fail("invalid option metadata: " + metadata.command + ":" + option.name)
    }
    names.insert(option.name)
    if option.default_binding is Some(binding) {
      guard option.default_value is Some(value) &&
        (
          ["Int32", "Bool", "String", "Bytes"].contains(binding.type_) ||
          binding.variant is Some(_)
        ) &&
        !binding.name.is_empty() &&
        binding.name.iter().all(char => char is ('A'..<='Z' | '0'..<='9' | '_')) else {
        fail("invalid generated default: " + option.name)
      }
      if binding.variant is Some(variant) {
        guard !variant.is_empty() &&
          !binding.type_.is_empty() &&
          [variant, binding.type_].all(name => {
            name[0] is ('A'..<='Z') &&
            name
            .iter()
            .all(char => char is ('a'..<='z' | 'A'..<='Z' | '0'..<='9'))
          }) &&
          binding.scale is None else {
          fail("invalid enum default")
        }
      }
      if binding.type_ == "Bool" {
        guard ["true", "false"].contains(value) else {
          fail("invalid boolean default")
        }
      } else if binding.type_ == "Int32" {
        guard !value.is_empty() &&
          value.iter().all(char => char is ('0'..<='9')) else {
          fail("invalid integer default")
        }
      }
    }
    guard option.aliases.all(spelling => {
      spelling.has_prefix("-") && spelling != "-"
    }) else {
      fail("invalid option alias: " + option.name)
    }
    if option.short is Some(short) {
      guard short.length() == 1 else { fail("invalid short option") }
    }
    if option.rg is Some(rg) {
      guard [
          "Input", "Search", "Filter", "Output", "OutputModes", "Indexing", "Logging",
          "OtherBehaviors",
        ].contains(rg.category) &&
        ["Other", "Filename", "Executable", "Filetype", "Encoding"].contains(
          rg.completion,
        ) else {
        fail("invalid rg metadata enum")
      }
    }
    if option.typst is Some(spec) {
      guard ["flag", "opt", "opt_optional"].contains(spec.builder) &&
        ["Required", "Pass"].contains(spec.empty) &&
        spec.dynamic.all(name => {
          ["validate", "delimiter", "possible"].contains(name)
        }) else {
        fail("invalid typst metadata adapter")
      }
    }
  }
  guard names.contains("help") && names.contains("version") else {
    fail("missing metadata options")
  }
  if metadata.readme_options is Some(selected) {
    for name in selected {
      guard names.contains(name) else { fail("missing README option: " + name) }
    }
  }
  let functions : Set[String] = Set([])
  for table in metadata.tables {
    guard !table.options.is_empty() && !table.function_name.is_empty() else {
      fail("empty parser table")
    }
    guard !functions.contains(table.function_name) else {
      fail("duplicate parser table")
    }
    functions.insert(table.function_name)
    for name in table.options {
      guard names.contains(name) else { fail("missing parser option: " + name) }
      let option = metadata.options
        .iter()
        .find_first(option => option.name == name)
        .unwrap()
      guard ["none", "required"].contains(option.value) else {
        fail("special value grammar requires a command adapter")
      }
    }
  }
}
