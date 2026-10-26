///|
pub(all) enum SpecialMode {
  HelpShort
  HelpLong
  VersionShort
  VersionLong
  VersionPCRE2
} derive(Debug, Eq)

///|
pub(all) enum SearchMode {
  Standard
  FilesWithMatches
  FilesWithoutMatch
  Count
  CountMatches
  JSON
} derive(Debug, Eq)

///|
pub(all) enum GenerateMode {
  Man
  CompleteBash
  CompleteZsh
  CompleteFish
  CompletePowerShell
} derive(Debug, Eq)

///|
pub(all) enum IndexMode {
  Crud
} derive(Debug, Eq)

///|
pub(all) enum Mode {
  Search(SearchMode)
  Index(IndexMode)
  Files
  Types
  Generate(GenerateMode)
} derive(Debug, Eq)

///|
fn Mode::updated(self : Mode, new : Mode) -> Mode {
  // Note: like ripgrep's `Mode::update`, any mode overrides the current
  // one (the non-search branch's check is on the current mode, so it always
  // succeeds).
  ignore(self)
  new
}

///|
pub(all) enum BinaryMode {
  Auto
  SearchAndSuppress
  AsText
} derive(Debug, Eq)

///|
pub(all) enum BoundaryMode {
  Line
  Word
} derive(Debug, Eq)

///|
pub(all) enum BufferMode {
  Auto
  Line
  Block
} derive(Debug, Eq)

///|
pub(all) enum CaseMode {
  Sensitive
  Insensitive
  Smart
} derive(Debug, Eq)

///|
pub(all) enum ColorChoice {
  Never
  Auto
  Always
  Ansi
} derive(Debug, Eq)

///|
/// Limited context settings: `-B`, `-A` and `-C`.
pub(all) struct ContextModeLimited {
  before : Int32?
  after : Int32?
  both : Int32?
} derive(Debug, Eq)

///|
pub fn ContextModeLimited::get(self : ContextModeLimited) -> (Int32, Int32) {
  let mut before = 0
  let mut after = 0
  if self.both is Some(n) {
    before = n
    after = n
  }
  if self.before is Some(n) {
    before = n
  }
  if self.after is Some(n) {
    after = n
  }
  (before, after)
}

///|
pub(all) enum ContextMode {
  Passthru
  Limited(ContextModeLimited)
} derive(Debug, Eq)

///|
pub fn ContextMode::default() -> ContextMode {
  Limited({ before: None, after: None, both: None, })
}

///|
fn ContextMode::set_before(self : ContextMode, lines : Int32) -> ContextMode {
  match self {
    Passthru => Limited({ before: Some(lines), after: None, both: None, })
    Limited(l) => Limited({ ..l, before: Some(lines), })
  }
}

///|
fn ContextMode::set_after(self : ContextMode, lines : Int32) -> ContextMode {
  match self {
    Passthru => Limited({ before: None, after: Some(lines), both: None, })
    Limited(l) => Limited({ ..l, after: Some(lines), })
  }
}

///|
fn ContextMode::set_both(self : ContextMode, lines : Int32) -> ContextMode {
  match self {
    Passthru => Limited({ before: None, after: None, both: Some(lines), })
    Limited(l) => Limited({ ..l, both: Some(lines), })
  }
}

///|
pub(all) enum EncodingMode {
  Auto
  Specific(@searcher.Encoding)
  Disabled
}

///|
pub(all) enum EngineChoice {
  Default
  Auto
  PCRE2
} derive(Debug, Eq)

///|
pub(all) enum LoggingMode {
  Debug
  Trace
} derive(Debug, Eq)

///|
pub(all) enum MmapMode {
  Auto
  AlwaysTryMmap
  Never
} derive(Debug, Eq)

///|
pub(all) enum PatternSource {
  Regexp(String)
  File(String)
} derive(Debug, Eq)

///|
pub(all) enum SortModeKind {
  Path
  LastModified
  LastAccessed
  Created
} derive(Debug, Eq)

///|
pub(all) struct SortMode {
  reverse : Bool
  kind : SortModeKind
} derive(Debug, Eq)

///|
pub(all) enum TypeChange {
  Clear(String)
  Add(String)
  Select(String)
  Negate(String)
} derive(Debug, Eq)

///|
/// Low level arguments: a direct representation of the flags given.
pub(all) struct LowArgs {
  mut special : SpecialMode?
  mut mode : Mode
  positional : Array[String]
  patterns : Array[PatternSource]
  mut binary : BinaryMode
  mut boundary : BoundaryMode?
  mut buffer : BufferMode
  mut byte_offset : Bool
  mut case : CaseMode
  mut color : ColorChoice
  colors : Array[String]
  mut column : Bool?
  mut context : ContextMode
  mut context_separator : Bytes?
  mut crlf : Bool
  mut dfa_size_limit : UInt64?
  mut encoding : EncodingMode
  mut engine : EngineChoice
  mut field_context_separator : Bytes
  mut field_match_separator : Bytes
  mut fixed_strings : Bool
  mut follow : Bool
  mut glob_case_insensitive : Bool
  globs : Array[String]
  mut heading : Bool?
  mut hidden : Bool
  mut hostname_bin : String?
  mut hyperlink_format : String
  iglobs : Array[String]
  ignore_file : Array[String]
  mut ignore_file_case_insensitive : Bool
  mut include_zero : Bool
  mut index : Int32
  mut index_force : Bool
  mut index_path : String?
  mut invert_match : Bool
  mut line_number : Bool?
  mut logging : LoggingMode?
  mut max_columns : UInt64?
  mut max_columns_preview : Bool
  mut max_count : UInt64?
  mut max_depth : Int32?
  mut max_filesize : UInt64?
  mut mmap : MmapMode
  mut multiline : Bool
  mut multiline_dotall : Bool
  mut no_config : Bool
  mut no_ignore_dot : Bool
  mut no_ignore_exclude : Bool
  mut no_ignore_files : Bool
  mut no_ignore_global : Bool
  mut no_ignore_messages : Bool
  mut no_ignore_parent : Bool
  mut no_ignore_vcs : Bool
  mut no_messages : Bool
  mut no_require_git : Bool
  mut no_unicode : Bool
  mut null : Bool
  mut null_data : Bool
  mut one_file_system : Bool
  mut only_matching : Bool
  mut path_separator : Byte?
  mut pre : String?
  pre_glob : Array[String]
  mut quiet : Bool
  mut regex_size_limit : UInt64?
  mut replace : Bytes?
  mut search_zip : Bool
  mut sort : SortMode?
  mut stats : Bool
  mut stop_on_nonmatch : Bool
  mut threads : Int32?
  mut trim : Bool
  type_changes : Array[TypeChange]
  mut unrestricted : Int32
  mut vimgrep : Bool
  mut with_filename : Bool?
}

///|
pub fn LowArgs::default() -> LowArgs {
  {
    special: None,
    mode: Search(Standard),
    positional: [],
    patterns: [],
    binary: Auto,
    boundary: None,
    buffer: Auto,
    byte_offset: false,
    case: Sensitive,
    color: Auto,
    colors: [],
    column: None,
    context: ContextMode::default(),
    context_separator: Some(b"--"),
    crlf: false,
    dfa_size_limit: None,
    encoding: Auto,
    engine: Default,
    field_context_separator: b"-",
    field_match_separator: b":",
    fixed_strings: false,
    follow: false,
    glob_case_insensitive: false,
    globs: [],
    heading: None,
    hidden: false,
    hostname_bin: None,
    hyperlink_format: "",
    iglobs: [],
    ignore_file: [],
    ignore_file_case_insensitive: false,
    include_zero: false,
    index: 0,
    index_force: false,
    index_path: None,
    invert_match: false,
    line_number: None,
    logging: None,
    max_columns: None,
    max_columns_preview: false,
    max_count: None,
    max_depth: None,
    max_filesize: None,
    mmap: Auto,
    multiline: false,
    multiline_dotall: false,
    no_config: false,
    no_ignore_dot: false,
    no_ignore_exclude: false,
    no_ignore_files: false,
    no_ignore_global: false,
    no_ignore_messages: false,
    no_ignore_parent: false,
    no_ignore_vcs: false,
    no_messages: false,
    no_require_git: false,
    no_unicode: false,
    null: false,
    null_data: false,
    one_file_system: false,
    only_matching: false,
    path_separator: None,
    pre: None,
    pre_glob: [],
    quiet: false,
    regex_size_limit: None,
    replace: None,
    search_zip: false,
    sort: None,
    stats: false,
    stop_on_nonmatch: false,
    threads: None,
    trim: false,
    type_changes: [],
    unrestricted: 0,
    vimgrep: false,
    with_filename: None,
  }
}

///|
pub impl Eq for EncodingMode with fn equal(self, other) {
  match (self, other) {
    (Auto, Auto) | (Disabled, Disabled) => true
    (Specific(a), Specific(b)) => a.name() == b.name()
    _ => false
  }
}

///|
pub impl Debug for EncodingMode with fn to_repr(self) {
  match self {
    Auto => Repr::ctor("Auto", [])
    Disabled => Repr::ctor("Disabled", [])
    Specific(e) => Repr::ctor("Specific", [(None, Repr::string(e.name()))])
  }
}
