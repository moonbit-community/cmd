// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The command line arguments (upstream `typst-cli/src/args.rs`).

///|
/// The character typically used to separate path components in environment
/// variables.
fn env_path_sep() -> Char {
  if @platform.os() == Windows {
    ';'
  } else {
    ':'
  }
}

///|
/// The Typst version this port corresponds to.
let typst_version : String = "0.15.1"

///|
/// The upstream commit this port is pinned to (`UPSTREAM_REV`).
let upstream_commit : String = "e58a63af09032a486b12241d08ebd04131483221"

///|
/// `typst --version`.
fn version_line() -> String {
  "typst \{MODULE_VERSION}"
}

///|
/// Whether to use color.
priv enum ColorChoice {
  Auto
  Always
  Never
}

///|
/// The parsed command line arguments.
priv struct CliArguments {
  /// The command to run.
  command : Command
  /// Whether to use color. When set to `auto`, uses color if the terminal
  /// supports it.
  color : ColorChoice
}

///|
/// What to do.
// The arguments of `completions` are parsed (and validated) like
// upstream's, but the command is not supported by this build (README.md);
// upstream reads them in typst-cli/src/main.rs:78.
#warnings("-unused_field")
priv enum Command {
  /// Compiles an input file into a supported output format.
  Compile(CompileArgs)
  /// Watches an input file and recompiles on changes.
  Watch(WatchCommand)
  /// Initializes a new project from a template.
  Init(InitCommand)
  /// Processes an input file to extract provided metadata (deprecated, use
  /// `eval` instead).
  Query(QueryCommand)
  /// Evaluates a piece of Typst code, optionally in the context of a
  /// document.
  Eval(EvalCommand)
  /// Lists all discovered fonts in system and custom font paths.
  Fonts(FontsCommand)
  /// Self update the Typst CLI.
  Update
  /// Generates shell completion scripts.
  Completions(String)
  /// Displays debugging information about Typst.
  Info(InfoCommand)
}

///|
/// Initializes a new project from a template.
priv struct InitCommand {
  /// The template to use, e.g. `@preview/charged-ieee`.
  template : String
  /// The project directory, defaults to the template's name.
  dir : String?
  /// Arguments related to storage of packages in the system.
  package_args : PackageArgs
}

///|
/// Processes an input file to extract provided metadata.
priv struct QueryCommand {
  input : Input
  selector : String
  field : String?
  one : Bool
  format : SerializationFormat
  pretty : Bool
  target : Target
  world : WorldArgs
  process : ProcessArgs
}

///|
/// Evaluates a piece of Typst code.
priv struct EvalCommand {
  expression : String
  in_ : Input?
  target : Target
  format : EvalSerializationFormat
  pretty : Bool
  world : WorldArgs
  process : ProcessArgs
}

///|
/// Lists all discovered fonts in system and custom font paths.
priv struct FontsCommand {
  font : FontArgs
  variants : Bool
}

///|
/// Displays environment variables and default values Typst uses.
priv struct InfoCommand {
  format : SerializationFormat?
  pretty : Bool
}

///|
/// Watches an input file and recompiles on changes.
priv struct WatchCommand {
  /// Arguments for compilation.
  args : CompileArgs
  /// Stops the watcher from taking over the terminal.
  ///
  /// With this flag, the watcher will only ever print normal output lines,
  /// not clear or reconfigure the terminal.
  no_fullscreen : Bool
  /// Arguments for the HTTP server.
  server : ServerArgs
}

///|
/// Arguments for the HTTP server (upstream's `http-server` feature, which
/// the upstream executable is built with).
// The server itself is not ported: `no_reload` and `port` only configure
// it (typst-cli/src/compile.rs:222).
#warnings("-unused_field")
priv struct ServerArgs {
  /// Disables the built-in HTTP server for HTML export.
  no_serve : Bool
  /// Disables the injected live reload script for HTML export. The HTML
  /// that is written to disk isn't affected either way.
  no_reload : Bool
  /// The port where HTML is served.
  ///
  /// Defaults to the first free port in the range 3000-3005.
  port : Int32?
}

///|
/// Arguments for compilation and watching.
priv struct CompileArgs {
  input : Input
  output : Output?
  format : OutputFormat?
  world : WorldArgs
  pretty : Bool?
  pages : Array[@library.PageRange]?
  pdf_standard : Array[@library.PdfStandard]
  no_pdf_tags : Bool
  pdf_tagged : Bool?
  ppi : Double?
  make_deps : String?
  deps : Output?
  deps_format : DepsFormat
  process : ProcessArgs
  open : String??
  timings : String?
}

///|
/// Arguments for the construction of a world.
priv struct WorldArgs {
  root : String?
  inputs : Array[(String, String)]
  font : FontArgs
  package_args : PackageArgs
  creation_timestamp : Int64?
}

///|
/// Arguments for configuration the process of compilation itself.
// `jobs` only sizes upstream's rayon thread pool
// (typst-cli/src/world.rs:48); this port is single-threaded.
#warnings("-unused_field")
priv struct ProcessArgs {
  jobs : Int32?
  features : Array[@library.Feature]
  diagnostic_format : @kit.DiagnosticFormat
}

///|
/// Arguments related to where packages are stored in the system.
priv struct PackageArgs {
  package_path : String?
  package_cache_path : String?
}

///|
/// Common arguments to customize available fonts.
priv struct FontArgs {
  font_paths : Array[String?]
  ignore_system_fonts : Bool
  ignore_embedded_fonts : Bool
}

///|
/// An input that is either stdin or a real path.
priv enum Input {
  Stdin
  Path(String)
}

///|
// Upstream's `Display` (args.rs:592) is only used for the HTTP server of
// `watch` (compile.rs:217, `cfg(feature = "http-server")`), which is not
// ported.
#warnings("-unused_value")
fn Input::to_string(self : Input) -> String {
  match self {
    Stdin => "stdin"
    Path(path) => path
  }
}

///|
/// An output that is either stdout or a real path.
priv enum Output {
  Stdout
  Path(String)
}

///|
fn Output::to_string(self : Output) -> String {
  match self {
    Stdout => "stdout"
    Path(path) => path
  }
}

///|
/// Write data to the output.
async fn Output::write(
  self : Output,
  buffer : Bytes,
) -> Unit raise @platform.IoError {
  match self {
    Stdout => @platform.write_stdout(buffer)
    Path(path) => @platform.write_file(path, buffer)
  }
}

///|
/// Which format to use for the generated output.
#derive(Eq)
priv enum OutputFormat {
  Pdf
  Png
  Svg
  Html
  Bundle
}

///|
/// Which format to use for a generated dependency file.
priv enum DepsFormat {
  Json
  Zero
  Make
}

///|
/// The target to compile for.
priv enum Target {
  Paged
  Html
  Bundle
}

///|
/// Output file format for query and info commands.
priv enum SerializationFormat {
  Json
  Yaml
}

///|
/// Output file format for eval command.
priv enum EvalSerializationFormat {
  Json
  Yaml
  Raw
}

///|
let pdf_standard_names : ReadOnlyArray[(String, @library.PdfStandard)] = [
  ("1.4", V_1_4),
  ("1.5", V_1_5),
  ("1.6", V_1_6),
  ("1.7", V_1_7),
  ("2.0", V_2_0),
  ("a-1b", A_1b),
  ("a-1a", A_1a),
  ("a-2b", A_2b),
  ("a-2u", A_2u),
  ("a-2a", A_2a),
  ("a-3b", A_3b),
  ("a-3u", A_3u),
  ("a-3a", A_3a),
  ("a-4", A_4),
  ("a-4f", A_4f),
  ("a-4e", A_4e),
  ("ua-1", UA_1),
]

///|
/// Parses a page range (`Pages::from_str`): `1-3`, `4`, `5-`, `-2`.
fn parse_pages(value : String) -> @library.PageRange raise CliError {
  let parts = value.split("-").map(s => @kit.rust_trim(s.to_owned())).to_array()
  let err = (msg : String) => {
    Invalid("invalid value '\{value}' for '--pages <PAGES>': \{msg}")
  }
  match parts {
    [] | [""] => raise err("page range must not be empty")
    [single_page] => {
      let page_number = saturate(parse_page_number(single_page, err))
      { start: Some(page_number), end: Some(page_number), }
    }
    ["", ""] => raise err("page range must have start or end")
    [start, ""] =>
      { start: Some(saturate(parse_page_number(start, err))), end: None, }
    ["", end] =>
      { start: None, end: Some(saturate(parse_page_number(end, err))), }
    [start, end] => {
      let start = parse_page_number(start, err)
      let end = parse_page_number(end, err)
      if start > end {
        raise err("page range must end at a page after the start")
      }
      { start: Some(saturate(start)), end: Some(saturate(end)), }
    }
    _ => raise err("page range must have a single hyphen")
  }
}

///|
/// Parses a single page number.
fn parse_page_number(
  value : String,
  err : (String) -> CliError,
) -> UInt64 raise CliError {
  if value == "0" {
    raise err("page numbers start at one")
  }
  match parse_usize(value) {
    Some(n) if n > 0UL => n
    _ => raise err("not a valid page number")
  }
}

///|
/// A page number or job count as an `Int` (values beyond `Int` saturate;
/// no document has that many pages).
fn saturate(n : UInt64) -> Int32 {
  if n > 2147483647UL {
    2147483647
  } else {
    n.to_int()
  }
}

///|
/// Rust's `usize::from_str` (64-bit).
fn parse_usize(value : String) -> UInt64? {
  let value = if value.has_prefix("+") { value[1:].to_owned() } else { value }
  if value == "" {
    return None
  }
  let mut n = 0UL
  for c in value {
    if c < '0' || c > '9' {
      return None
    }
    let digit = (c.to_int() - '0'.to_int()).to_uint64()
    if n > (18446744073709551615UL - digit) / 10UL {
      return None
    }
    n = n * 10UL + digit
  }
  Some(n)
}

///|
/// Rust's `i64::from_str`, with the error message of `ParseIntError`.
fn parse_i64(value : String) -> Int64 raise @kit.StrError {
  let (neg, digits) = if value.has_prefix("-") {
    (true, value[1:].to_owned())
  } else if value.has_prefix("+") {
    (false, value[1:].to_owned())
  } else {
    (false, value)
  }
  if value == "" {
    raise @kit.StrError("cannot parse integer from empty string")
  }
  if digits == "" {
    raise @kit.StrError("invalid digit found in string")
  }
  let mut n = 0UL
  for c in digits {
    if c < '0' || c > '9' {
      raise @kit.StrError("invalid digit found in string")
    }
    let digit = (c.to_int() - '0'.to_int()).to_uint64()
    if n > (9223372036854775808UL - digit) / 10UL {
      raise @kit.StrError(
        if neg {
          "number too small to fit in target type"
        } else {
          "number too large to fit in target type"
        },
      )
    }
    n = n * 10UL + digit
  }
  if !neg && n == 9223372036854775808UL {
    raise @kit.StrError("number too large to fit in target type")
  }
  if neg {
    -n.reinterpret_as_int64()
  } else {
    n.reinterpret_as_int64()
  }
}

///|
/// The common world arguments.
fn world_specs() -> Array[ArgSpec] {
  [
    argument_root(),
    argument_input(validate=v => parse_input_pair(v) |> ignore),
    ..font_specs(),
    ..package_specs(),
    argument_creation_timestamp(validate=v => parse_timestamp(v) |> ignore),
  ]
}

///|
fn font_specs() -> Array[ArgSpec] {
  [
    argument_font_path(delimiter=env_path_sep()),
    argument_ignore_system_fonts(),
    argument_ignore_embedded_fonts(),
  ]
}

///|
fn package_specs() -> Array[ArgSpec] {
  [argument_package_path(), argument_package_cache_path()]
}

///|
fn process_specs() -> Array[ArgSpec] {
  [
    argument_jobs(validate=v => parse_jobs(v) |> ignore),
    argument_features(),
    argument_diagnostic_format(),
  ]
}

///|
fn compile_spec(path : String, about : String, watch : Bool) -> CommandSpec {
  let args = [
    argument_format_compile(),
    ..world_specs(),
    argument_pretty_compile(),
    argument_pages(validate=v => parse_pages(v) |> ignore),
    argument_pdf_standard(possible=pdf_standard_names[:].map(p => p.0)),
    argument_no_pdf_tags(),
    argument_pdf_tagged(),
    argument_ppi(validate=v => parse_ppi(v) |> ignore),
    argument_make_deps(),
    argument_deps(validate=v => parse_output(v, "--deps <PATH>") |> ignore),
    argument_deps_format(),
    ..process_specs(),
    argument_open(),
    argument_timings(),
  ]
  if watch {
    args.push(argument_no_fullscreen())
    args.push(argument_no_serve())
    args.push(argument_no_reload())
    args.push(argument_port(validate=v => parse_port(v) |> ignore))
  }
  {
    key: if watch {
      "watch"
    } else {
      "compile"
    },
    path,
    about,
    args,
    positionals: [
      {
        name: "INPUT",
        required: true,
        help: "Path to input Typst file. Use `-` to read input from stdin",
        validate: Some(v => parse_input(v, "<INPUT>") |> ignore),
      },
      {
        name: "OUTPUT",
        required: false,
        help: "Path to output file (PDF, PNG, SVG, or HTML). Use `-` to write output to stdout",
        validate: Some(v => parse_output(v, "[OUTPUT]") |> ignore),
      },
    ],
    subcommands: [],
  }
}

///|
fn main_spec() -> CommandSpec {
  {
    key: "",
    path: "typst",
    about: "The Typst compiler",
    args: [
      {
        ..argument_color(),
        // Upstream also sets `default_missing_value = "always"`
        // (args.rs:70), which clap never applies to an argument that
        // requires a value.
        kind: LooseValue,
      },
      argument_cert(),
    ],
    positionals: [],
    subcommands: [
      (
        "compile",
        ["c"],
        "Compiles an input file into a supported output format",
        false,
      ),
      ("watch", ["w"], "Watches an input file and recompiles on changes", false),
      ("init", [], "Initializes a new project from a template", false),
      (
        "query",
        [],
        "Processes an input file to extract provided metadata (deprecated, use `eval` instead)",
        true,
      ),
      (
        "eval",
        [],
        "Evaluates a piece of Typst code, optionally in the context of a document",
        false,
      ),
      (
        "fonts",
        [],
        "Lists all discovered fonts in system and custom font paths",
        false,
      ),
      ("update", [], "Self update the Typst CLI", true),
      ("completions", [], "Generates shell completion scripts", false),
      ("info", [], "Displays debugging information about Typst", false),
    ],
  }
}

///|
/// Parses the command line (`CliArguments::try_parse`).
fn parse_args(argv : Array[String]) -> CliArguments raise CliError {
  let spec = main_spec()
  let matches = spec.parse(argv)
  guard matches.subcommand is Some((name, rest)) else {
    raise MissingSubcommand
  }
  let command = match name {
    "compile" | "c" => {
      let spec = compile_spec(
        "typst compile", "Compiles an input file into a supported output format",
        false,
      )
      Compile(compile_args(spec, spec.parse(rest)))
    }
    "watch" | "w" => {
      let spec = compile_spec(
        "typst watch", "Watches an input file and recompiles on changes", true,
      )
      let m = spec.parse(rest)
      Watch({
        args: compile_args(spec, m),
        no_fullscreen: m.flag("no-fullscreen"),
        server: {
          no_serve: m.flag("no-serve"),
          no_reload: m.flag("no-reload"),
          port: match m.value("port") {
            Some(v) => Some(parse_port(v))
            None => None
          },
        },
      })
    }
    "init" => {
      let spec : CommandSpec = {
        key: "init",
        path: "typst init",
        about: "Initializes a new project from a template",
        args: package_specs(),
        positionals: [
          {
            name: "TEMPLATE",
            required: true,
            help: "The template to use, e.g. `@preview/charged-ieee`",
            validate: None,
          },
          {
            name: "DIR",
            required: false,
            help: "The project directory, defaults to the template's name",
            validate: None,
          },
        ],
        subcommands: [],
      }
      let m = spec.parse(rest)
      guard m.positional(0) is Some(template) else {
        raise missing(spec, "TEMPLATE")
      }
      Init({ template, dir: m.positional(1), package_args: package_args(m), })
    }
    "query" => {
      let spec : CommandSpec = {
        key: "query",
        path: "typst query",
        about: "Processes an input file to extract provided metadata (deprecated, use `eval` instead)",
        args: [
          argument_field(),
          argument_one(),
          argument_format_query(),
          argument_pretty_query(),
          argument_target(),
          ..world_specs(),
          ..process_specs(),
        ],
        positionals: [
          {
            name: "INPUT",
            required: true,
            help: "Path to input Typst file. Use `-` to read input from stdin",
            validate: Some(v => parse_input(v, "<INPUT>") |> ignore),
          },
          {
            name: "SELECTOR",
            required: true,
            help: "Defines which elements to retrieve",
            validate: None,
          },
        ],
        subcommands: [],
      }
      let m = spec.parse(rest)
      guard m.positional(0) is Some(input) else { raise missing(spec, "INPUT") }
      guard m.positional(1) is Some(selector) else {
        raise missing(spec, "SELECTOR")
      }
      Query({
        input: parse_input(input, "<INPUT>"),
        selector,
        field: m.value("field"),
        one: m.flag("one"),
        format: if m.value("format") == Some("yaml") {
          Yaml
        } else {
          Json
        },
        pretty: m.flag("pretty"),
        target: parse_target(m),
        world: world_args(m),
        process: process_args(m),
      })
    }
    "eval" => {
      let spec : CommandSpec = {
        key: "eval",
        path: "typst eval",
        about: "Evaluates a piece of Typst code, optionally in the context of a document",
        args: [
          argument_in(validate=v => parse_input(v, "--in <IN>") |> ignore),
          argument_target_eval(),
          argument_format_eval(),
          argument_pretty_eval(),
          ..world_specs(),
          ..process_specs(),
        ],
        positionals: [
          {
            name: "EXPRESSION",
            required: true,
            help: "The piece of Typst code to evaluate",
            validate: None,
          },
        ],
        subcommands: [],
      }
      let m = spec.parse(rest)
      guard m.positional(0) is Some(expression) else {
        raise missing(spec, "EXPRESSION")
      }
      Eval({
        expression,
        in_: m.value("in").map(v => parse_input(v, "--in <IN>")),
        target: parse_target(m),
        format: match m.value("format") {
          Some("yaml") => Yaml
          Some("raw") => Raw
          _ => Json
        },
        pretty: m.flag("pretty"),
        world: world_args(m),
        process: process_args(m),
      })
    }
    "fonts" => {
      let spec : CommandSpec = {
        key: "fonts",
        path: "typst fonts",
        about: "Lists all discovered fonts in system and custom font paths",
        args: [..font_specs(), argument_variants()],
        positionals: [],
        subcommands: [],
      }
      let m = spec.parse(rest)
      Fonts({ font: font_args(m), variants: m.flag("variants"), })
    }
    "update" => {
      let spec : CommandSpec = {
        key: "update",
        path: "typst update",
        about: "Self update the Typst CLI",
        args: [argument_force(), argument_revert(), argument_backup_path()],
        positionals: [
          {
            name: "VERSION",
            required: false,
            help: "Which version to update to (defaults to latest)",
            validate: Some(v => parse_semver(v)),
          },
        ],
        subcommands: [],
      }
      let m = spec.parse(rest)
      check_update_conflicts(rest, m)
      Update
    }
    "completions" => {
      let spec : CommandSpec = {
        key: "completions",
        path: "typst completions",
        about: "Generates shell completion scripts",
        args: [],
        positionals: [
          {
            name: "SHELL",
            required: true,
            help: "The shell to generate completions for",
            validate: Some(v => parse_shell(v)),
          },
        ],
        subcommands: [],
      }
      let m = spec.parse(rest)
      guard m.positional(0) is Some(shell) else { raise missing(spec, "SHELL") }
      Completions(shell)
    }
    "info" => {
      let spec : CommandSpec = {
        key: "info",
        path: "typst info",
        about: "Displays debugging information about Typst",
        args: [argument_format_info(), argument_pretty_info()],
        positionals: [],
        subcommands: [],
      }
      let m = spec.parse(rest)
      Info({
        format: match m.value("format") {
          Some("json") => Some(Json)
          Some("yaml") => Some(Yaml)
          _ => None
        },
        pretty: m.flag("pretty"),
      })
    }
    "help" =>
      match rest {
        [] => raise Display(spec.help())
        [sub, .. more] => {
          if sub == "help" {
            if more is [next, ..] {
              raise Usage(
                "unrecognized subcommand '\{next}'",
                "typst help [COMMAND]...",
              )
            }
            raise Display(
              "Print this message or the help of the given subcommand(s)\n\nUsage: typst help [COMMAND]...\n",
            )
          }
          guard spec.subcommands
            .iter()
            .find_first(s => s.0 == sub || s.1.contains(sub))
            is Some((key, _, _, _)) else {
            raise Usage("unrecognized subcommand '\{sub}'", spec.usage())
          }
          let sub_spec = { ..spec, key, subcommands: [], }
          if more is [next, ..] {
            raise Usage("unrecognized subcommand '\{next}'", sub_spec.usage())
          }
          raise Display(sub_spec.help())
        }
      }
    other => raise Usage("unrecognized subcommand '\{other}'", spec.usage())
  }
  matches.resolve_pending()
  let color = match matches.value("color") {
    None | Some("auto") => default_color()
    Some("always") => Always
    Some("never") => Never
    Some(other) =>
      raise Invalid(
        "invalid value '\{other}' for '--color <COLOR>'\n  [possible values: auto, always, never]",
      )
  }
  { command, color, }
}

///|
fn parse_input(value : String, name : String) -> Input raise CliError {
  if value == "" {
    raise Invalid(
      "invalid value '' for '\{name}': error: one of the values isn't valid for an argument\n",
    )
  } else if value == "-" {
    Stdin
  } else {
    Path(value)
  }
}

///|
fn parse_output(value : String, name : String) -> Output raise CliError {
  if value == "" {
    raise Invalid(
      "invalid value '' for '\{name}': error: one of the values isn't valid for an argument\n",
    )
  } else if value == "-" {
    Stdout
  } else {
    Path(value)
  }
}

///|
fn parse_target(m : Matches) -> Target {
  match m.value("target") {
    Some("html") => Html
    Some("bundle") => Bundle
    _ => default_target()
  }
}

///|
fn parse_bool(value : String, name : String) -> Bool raise CliError {
  match value {
    "true" => true
    "false" => false
    _ =>
      raise Invalid(
        "invalid value '\{value}' for '--\{name}[=<\{name.to_upper().replace_all(old="-", new="_")}>]'\n  [possible values: true, false]",
      )
  }
}

///|
fn compile_args(spec : CommandSpec, m : Matches) -> CompileArgs raise CliError {
  guard m.positional(0) is Some(input) else { raise missing(spec, "INPUT") }
  let input = parse_input(input, "<INPUT>")
  let output = match m.positional(1) {
    Some(output) => Some(parse_output(output, "[OUTPUT]"))
    None => None
  }
  if input is Stdin && output is None {
    raise Usage(
      "the following required arguments were not provided:\n  <OUTPUT>",
      spec.required_usage(output_required=true),
    )
  }
  let format : OutputFormat? = match m.value("format") {
    Some("pdf") => Some(Pdf)
    Some("png") => Some(Png)
    Some("svg") => Some(Svg)
    Some("html") => Some(Html)
    Some("bundle") => Some(Bundle)
    _ => None
  }
  let pages = if m.values.contains("pages") {
    Some(m.all("pages").map(v => parse_pages(v)))
  } else {
    None
  }
  let pdf_standard = m
    .all("pdf-standard")
    .map(v => pdf_standard_names.iter().find_first(p => p.0 == v).unwrap().1)
  let ppi = match m.value("ppi") {
    Some(v) => Some(parse_ppi(v))
    None => None
  }
  let deps_format : DepsFormat = match m.value("deps-format") {
    Some("zero") => Zero
    Some("make") => Make
    _ => default_deps_format()
  }
  {
    input,
    output,
    format,
    world: world_args(m),
    pretty: match m.value("pretty") {
      Some(v) => Some(parse_bool(v, "pretty"))
      None => None
    },
    pages,
    pdf_standard,
    no_pdf_tags: m.flag("no-pdf-tags"),
    pdf_tagged: match m.value("pdf-tagged") {
      Some(v) => Some(parse_bool(v, "pdf-tagged"))
      None => None
    },
    ppi,
    make_deps: m.value("make-deps"),
    deps: match m.value("deps") {
      Some(v) => Some(parse_output(v, "--deps <PATH>"))
      None => None
    },
    deps_format,
    process: process_args(m),
    open: match m.value("open") {
      Some("") => Some(None)
      Some(v) => Some(Some(v))
      None => None
    },
    timings: m.value("timings"),
  }
}

///|
fn world_args(m : Matches) -> WorldArgs raise CliError {
  let inputs = []
  for raw in m.all("input") {
    inputs.push(parse_input_pair(raw))
  }
  let creation_timestamp = match m.value("creation-timestamp") {
    Some(v) => Some(parse_timestamp(v))
    None => None
  }
  {
    root: m.value("root"),
    inputs,
    font: font_args(m),
    package_args: package_args(m),
    creation_timestamp,
  }
}

///|
fn font_args(m : Matches) -> FontArgs {
  {
    // Empty paths are allowed (so that `--font-path ""` works) and turned
    // into `None`.
    font_paths: m
    .all("font-path")
    .map(p => if p == "" { None } else { Some(p) }),
    ignore_system_fonts: m.flag("ignore-system-fonts"),
    ignore_embedded_fonts: m.flag("ignore-embedded-fonts"),
  }
}

///|
fn package_args(m : Matches) -> PackageArgs {
  {
    package_path: m.value("package-path"),
    package_cache_path: m.value("package-cache-path"),
  }
}

///|
fn process_args(m : Matches) -> ProcessArgs raise CliError {
  let jobs = match m.value("jobs") {
    Some(v) => Some(parse_jobs(v))
    None => None
  }
  let features = []
  for f in m.all("features") {
    let feature : @library.Feature = match f {
      "html" => Html
      "bundle" => Bundle
      _ => A11yExtras
    }
    features.push(feature)
  }
  {
    jobs,
    features,
    diagnostic_format: if m.value("diagnostic-format") == Some("short") {
      Short
    } else {
      Human
    },
  }
}

///|
/// The value parser of `--jobs` (`usize`).
fn parse_jobs(v : String) -> Int32 raise CliError {
  match parse_usize(v) {
    Some(n) => saturate(n)
    None =>
      raise Invalid(
        "invalid value '\{v}' for '--jobs <JOBS>': \{usize_error(v)}",
      )
  }
}

///|
/// The value parser of `--port` (`u16`: clap parses an `i64` and checks the
/// range).
fn parse_port(v : String) -> Int32 raise CliError {
  let n = parse_i64(v) catch {
    @kit.StrError(msg) =>
      raise Invalid("invalid value '\{v}' for '--port <PORT>': \{msg}")
  }
  if n < 0L || n > 65535L {
    raise Invalid(
      "invalid value '\{v}' for '--port <PORT>': \{n} is not in 0..=65535",
    )
  }
  n.to_int()
}

///|
/// The value parser of `--ppi` (`f64`).
fn parse_ppi(v : String) -> Double raise CliError {
  match @library.rust_parse_f64(v) {
    Some(x) => x
    None if v == "" =>
      raise Invalid(
        "invalid value '' for '--ppi <PPI>': cannot parse float from empty string",
      )
    None =>
      raise Invalid(
        "invalid value '\{v}' for '--ppi <PPI>': invalid float literal",
      )
  }
}

///|
/// The value parser of `--creation-timestamp` (`i64`).
fn parse_timestamp(v : String) -> Int64 raise CliError {
  parse_i64(v) catch {
    @kit.StrError(msg) =>
      raise Invalid(
        "invalid value '\{v}' for '--creation-timestamp <UNIX_TIMESTAMP>': \{msg}",
      )
  }
}

///|
/// The value parser of `--input` (`typst_utils::parse_sys_input_pair`).
fn parse_input_pair(raw : String) -> (String, String) raise CliError {
  guard raw.find("=") is Some(eq) else {
    raise Invalid(
      "invalid value '\{raw}' for '--input <key=value>': input must be a key and a value separated by an equal sign",
    )
  }
  let key = @kit.rust_trim(raw[:eq].to_owned())
  if key == "" {
    raise Invalid(
      "invalid value '\{raw}' for '--input <key=value>': the key was missing or empty",
    )
  }
  let val = @kit.rust_trim(raw[eq + 1:].to_owned())
  (key, val)
}

///|
/// The value parser of the shell of `completions` (`ValueEnum`).
fn parse_shell(v : String) -> Unit raise CliError {
  let shells = ["bash", "elvish", "fish", "nushell", "powershell", "zsh"]
  if !shells.contains(v) {
    raise Invalid(
      "invalid value '\{v}' for '<SHELL>'\n  [possible values: \{shells.join(", ")}]",
    )
  }
}

///|
/// The message of Rust's `ParseIntError` for an invalid `usize`.
fn usize_error(v : String) -> String {
  let digits = if v.has_prefix("+") { v[1:].to_owned() } else { v }
  if v == "" {
    "cannot parse integer from empty string"
  } else if digits != "" && digits.all(c => c >= '0' && c <= '9') {
    "number too large to fit in target type"
  } else {
    "invalid digit found in string"
  }
}

///|
/// clap's conflict validation of `update` (`--revert` conflicts with
/// `--force` and `[VERSION]`): the first of the conflicting arguments on the
/// command line is reported with the ones it conflicts with.
fn check_update_conflicts(
  argv : Array[String],
  m : Matches,
) -> Unit raise CliError {
  // The used arguments in the order of their first occurrence.
  let order : Array[String] = []
  let note = (id : String) => if !order.contains(id) { order.push(id) }
  let mut i = 0
  let mut only_positional = false
  while i < argv.length() {
    let arg = argv[i]
    i += 1
    if !only_positional && arg == "--" {
      only_positional = true
    } else if !only_positional && arg.has_prefix("--") && arg != "--" {
      let name = match arg.find("=") {
        Some(eq) => arg[2:eq].to_owned()
        None => arg[2:].to_owned()
      }
      match name {
        "revert" | "force" => note(name)
        "backup-path" => {
          note(name)
          if arg.find("=") is None {
            i += 1
          }
        }
        _ => ()
      }
    } else if only_positional || !arg.has_prefix("-") || arg == "-" {
      note("version")
    }
  }
  let present = (id : String) => {
    match id {
      "revert" => m.flag("revert")
      "force" => m.flag("force")
      "version" => m.positional(0) is Some(_)
      _ => false
    }
  }
  let conflicts = (a : String, b : String) => {
    (a == "revert" && (b == "force" || b == "version")) ||
    (b == "revert" && (a == "force" || a == "version"))
  }
  let display = (id : String) => {
    match id {
      "revert" => "--revert"
      "force" => "--force"
      "backup-path" => "--backup-path <FILE>"
      _ => "[VERSION]"
    }
  }
  for subject in order {
    if !present(subject) {
      continue
    }
    let others = order.filter(o => present(o) && conflicts(subject, o))
    if others.is_empty() {
      continue
    }
    let message = if others.length() == 1 {
      "the argument '\{display(subject)}' cannot be used with '\{display(others[0])}'"
    } else {
      "the argument '\{display(subject)}' cannot be used with:" +
      others.map(o => "\n  \{display(o)}").join("")
    }
    let usage = StringBuilder()
    usage.write_string("typst update")
    for id in order {
      if id != "version" &&
        !others.contains(id) &&
        (id == "backup-path" || present(id)) {
        usage.write_string(" \{display(id)}")
      }
    }
    if order.contains("version") && !others.contains("version") {
      usage.write_string(" <VERSION>")
    } else {
      usage.write_string(" [VERSION]")
    }
    raise Usage(message, usage.to_string())
  }
}
