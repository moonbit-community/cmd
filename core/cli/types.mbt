///|
pub(all) enum CompatibilityTier {
  Core
  Extended
  Restricted
} derive(Eq, Debug)

///|
pub(all) enum InputMode {
  NoInput
  OptionalStdin
  FileOrStdin
  StructuredInput
} derive(Eq, Debug)

///|
pub(all) enum OutputMode {
  ByteStream
  LineStream
  StructuredOutput
} derive(Eq, Debug)

///|
pub(all) enum Capability {
  FileRead
  FileWrite
  ProcessSpawn
  Network
  PermissionMutation
  SymbolicLink
  ProcessGroupCancellation
} derive(Eq, Debug)

///|
pub(all) enum ErrorKind {
  UnknownOption
  MissingOptionValue
  UnexpectedOptionValue
  DuplicateOption
  InvalidValue
  MissingOperand
  UnsupportedCapability
} derive(Eq, Debug)

///|
pub(all) suberror CliError {
  CliError(kind~ : ErrorKind, option~ : String, message~ : String)
} derive(Eq, Debug)

///|
pub(all) struct OptionSpec {
  name : String
  short : Char?
  takes_value : Bool
  repeatable : Bool
  allow_attached : Bool
}

///|
pub fn flag(
  name : String,
  short? : Char,
  repeatable? : Bool = true,
) -> OptionSpec {
  { name, short, takes_value: false, repeatable, allow_attached: false, }
}

///|
pub fn option(
  name : String,
  short? : Char,
  repeatable? : Bool = true,
  allow_attached? : Bool = true,
) -> OptionSpec {
  { name, short, takes_value: true, repeatable, allow_attached, }
}

///|
pub(all) struct ParsedArgs {
  occurrences : Map[String, Array[String?]]
  operands : Array[String]
  order : Array[String]
}

///|
pub fn ParsedArgs::contains(self : ParsedArgs, name : String) -> Bool {
  self.occurrences.contains(name)
}

///|
pub fn ParsedArgs::last_value(self : ParsedArgs, name : String) -> String? {
  guard self.occurrences.get(name) is Some(values) else { return None }
  for index = values.length() - 1; index >= 0; index = index - 1 {
    if values[index] is Some(value) {
      return Some(value)
    }
  }
  None
}

///|
pub fn ParsedArgs::values(self : ParsedArgs, name : String) -> Array[String] {
  let result : Array[String] = []
  guard self.occurrences.get(name) is Some(values) else { return result }
  for value in values {
    if value is Some(text) {
      result.push(text)
    }
  }
  result
}

///|
pub fn ParsedArgs::last_occurrence(
  self : ParsedArgs,
  names : Array[String],
) -> String? {
  for index = self.order.length() - 1; index >= 0; index = index - 1 {
    let candidate = self.order[index]
    if names.contains(candidate) {
      return Some(candidate)
    }
  }
  None
}

///|
pub(all) struct CommandContract {
  name : String
  tier : CompatibilityTier
  input : InputMode
  output : OutputMode
  exit_codes : Array[Int]
  capabilities : Array[Capability]
  options : Array[String]
}
