///|
/// The category of a flag, used for documentation.
pub(all) enum Category {
  Input
  Search
  Filter
  Output
  OutputModes
  Indexing
  Logging
  OtherBehaviors
} derive(Debug, Eq, Compare)

///|
pub fn Category::as_str(self : Category) -> String {
  match self {
    Input => "input"
    Search => "search"
    Filter => "filter"
    Output => "output"
    OutputModes => "output-modes"
    Indexing => "indexing"
    Logging => "logging"
    OtherBehaviors => "other-behaviors"
  }
}

///|
/// The kind of completion to use for a flag's value.
pub(all) enum CompletionType {
  Other
  Filename
  Executable
  Filetype
  Encoding
} derive(Debug, Eq)

///|
/// Static metadata about a flag.
pub(all) struct FlagDef {
  is_switch : Bool
  name_short : Char?
  name_long : String
  aliases : Array[String]
  name_negated : String?
  doc_variable : String?
  doc_category : Category
  doc_short : String
  doc_long : String
  doc_choices : Array[String]
  completion_type : CompletionType
}

///|
/// The value given to a flag.
pub(all) enum FlagValue {
  Switch(Bool)
  Value(String)
} derive(Debug, Eq)

///|
fn FlagValue::unwrap_switch(self : FlagValue) -> Bool {
  match self {
    Switch(b) => b
    Value(_) => abort("got flag value but expected switch")
  }
}

///|
fn FlagValue::unwrap_value(self : FlagValue) -> String {
  match self {
    Value(v) => v
    Switch(_) => abort("got switch but expected flag value")
  }
}

///|
const INDEXING_NOT_SUPPORTED : String = "Indexing is not supported in this build of ripgrep."
