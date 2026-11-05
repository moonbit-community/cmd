///|
let command_help : String =
  #|Usage: typst [OPTIONS] <COMMAND>
  #|
  #|Compile Typst documents with the MoonBit typesetting engine.
  #|
  #|Commands:
  #|  compile, c   Compile to PDF, PNG, SVG, HTML or a bundle
  #|  watch, w     Recompile when input dependencies change
  #|  eval         Evaluate Typst code
  #|  query        Query document elements
  #|  fonts        List available fonts
  #|  info         Show configuration and engine information
  #|  init         Initialize from a locally installed template
  #|  help         Show help for a command
  #|
  #|Options:
  #|      --color <auto|always|never>  Diagnostic colors (auto is uncolored)
  #|  -h, --help                       Show help
  #|  -V, --version                    Show cli/typst package version
  #|
  #|Use 'typst help <COMMAND>' for command options.
  #|Packages must be installed locally; network downloads, update, completions,
  #|--open, --timings and the watch HTTP server are unsupported.
  #|Use --no-serve for HTML watch. --jobs does not enable parallel compilation.
  #|Wasm uses lexical paths, cannot detect symlinks, and assumes local time UTC.
