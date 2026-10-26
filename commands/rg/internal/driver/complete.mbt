///|
/// Hyperlink aliases (name, description), in the printer's table order.
let hyperlink_alias_descriptions : Array[(String, String)] = [
  ("cursor", "Cursor scheme (cursor://)"),
  ("default", "RFC 8089 scheme (file://) (platform-aware)"),
  ("file", "RFC 8089 scheme (file://) with host"),
  ("grep+", "grep+ scheme (grep+://)"),
  ("kitty", "kitty-style RFC 8089 scheme (file://) with line number"),
  ("macvim", "MacVim scheme (mvim://)"),
  ("none", "disable hyperlinks"),
  ("textmate", "TextMate scheme (txmt://)"),
  ("vscode", "VS Code scheme (vscode://)"),
  ("vscode-insiders", "VS Code Insiders scheme (vscode-insiders://)"),
  ("vscodium", "VSCodium scheme (vscodium://)"),
]

///|
let bash_template_full : String =
  #|
  #|_rg() {
  #|  local i cur prev opts cmds
  #|  COMPREPLY=()
  #|  cur="${COMP_WORDS[COMP_CWORD]}"
  #|  prev="${COMP_WORDS[COMP_CWORD-1]}"
  #|  cmd=""
  #|  opts=""
  #|
  #|  for i in ${COMP_WORDS[@]}; do
  #|    case "${i}" in
  #|      rg)
  #|        cmd="rg"
  #|        ;;
  #|      *)
  #|        ;;
  #|    esac
  #|  done
  #|
  #|  case "${cmd}" in
  #|    rg)
  #|      opts="!OPTS!"
  #|      if [[ ${cur} == -* || ${COMP_CWORD} -eq 1 ]] ; then
  #|        COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
  #|        return 0
  #|      fi
  #|      case "${prev}" in
  #|!CASES!
  #|      esac
  #|      COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
  #|      return 0
  #|      ;;
  #|  esac
  #|}
  #|
  #|complete -F _rg -o bashdefault -o default rg
  #|

///|
let bash_template_case : String =
  #|
  #|        !FLAG!)
  #|          COMPREPLY=($(compgen -f "${cur}"))
  #|          return 0
  #|          ;;
  #|

///|
let bash_template_case_choices : String =
  #|
  #|        !FLAG!)
  #|          COMPREPLY=($(compgen -W "!CHOICES!" -- "${cur}"))
  #|          return 0
  #|          ;;
  #|

///|
pub fn generate_complete_bash() -> String {
  let opts = StringBuilder()
  for flag in flag_defs {
    opts.write_string("--\{flag.name_long} ")
    if flag.name_short is Some(c) {
      opts.write_string("-\{c} ")
    }
    if flag.name_negated is Some(n) {
      opts.write_string("--\{n} ")
    }
  }
  opts.write_string("<PATTERN> <PATH>...")
  let cases = StringBuilder()
  for flag in flag_defs {
    let template = if !flag.doc_choices.is_empty() {
      bash_template_case_choices
      .trim_end()
      .to_owned()
      .replace_all(old="!CHOICES!", new=flag.doc_choices.join(" "))
    } else {
      bash_template_case.trim_end().to_owned()
    }
    cases.write_string(
      template.replace_all(old="!FLAG!", new="--\{flag.name_long}"),
    )
    if flag.name_short is Some(c) {
      cases.write_string(template.replace_all(old="!FLAG!", new="-\{c}"))
    }
    if flag.name_negated is Some(n) {
      cases.write_string(template.replace_all(old="!FLAG!", new="--\{n}"))
    }
  }
  bash_template_full
  .replace_all(old="!OPTS!", new=opts.to_string())
  .replace_all(old="!CASES!", new=cases.to_string())
  .trim_start()
  .to_owned()
}

///|
pub fn generate_complete_fish() -> String {
  let out = StringBuilder()
  out.write_string(complete_fish_prelude)
  out.write_char('\n')
  for flag in flag_defs {
    let short = match flag.name_short {
      None => ""
      Some(c) => "-s \{c}"
    }
    let long = flag.name_long
    let doc = flag.doc_short.replace_all(old="'", new="\\'")
    let completion = StringBuilder()
    completion.write_string("complete -c rg \{short} -l \{long} -d '\{doc}'")
    match flag.completion_type {
      Filename => completion.write_string(" -r -F")
      Executable =>
        completion.write_string(" -r -f -a '(__fish_complete_command)'")
      Filetype =>
        completion.write_string(
          " -r -f -a '(rg --type-list | string replace : \\t)'",
        )
      Encoding => {
        completion.write_string(" -r -f -a '")
        completion.write_string(complete_encodings_sh)
        completion.write_string("'")
      }
      Other =>
        if !flag.doc_choices.is_empty() {
          completion.write_string(" -r -f -a '")
          completion.write_string(flag.doc_choices.join(" "))
          completion.write_string("'")
        } else if !flag.is_switch {
          completion.write_string(" -r -f")
        }
    }
    completion.write_char('\n')
    out.write_string(completion.to_string())
    if flag.name_negated is Some(negated) {
      let short = match flag.name_short {
        None => ""
        Some(c) => c.to_string()
      }
      out.write_string(
        "complete -c rg -l \{negated} -n '__rg_contains_opt \{long} \{short}' -d '\{doc}'\n",
      )
    }
  }
  out.to_string()
}

///|
pub fn generate_complete_zsh() -> String {
  let aliases = hyperlink_alias_descriptions
    .map(a => "    \{a.0}:\"\{a.1}\"")
    .join("\n")
  complete_zsh_template
  .replace_all(
    old="!ENCODINGS!",
    new=complete_encodings_sh.trim_end().to_owned(),
  )
  .replace_all(old="!HYPERLINK_ALIASES!", new=aliases)
}

///|
let powershell_template : String =
  #|
  #|using namespace System.Management.Automation
  #|using namespace System.Management.Automation.Language
  #|
  #|Register-ArgumentCompleter -Native -CommandName 'rg' -ScriptBlock {
  #|  param($wordToComplete, $commandAst, $cursorPosition)
  #|  $commandElements = $commandAst.CommandElements
  #|  $command = @(
  #|    'rg'
  #|    for ($i = 1; $i -lt $commandElements.Count; $i++) {
  #|        $element = $commandElements[$i]
  #|        if ($element -isnot [StringConstantExpressionAst] -or
  #|            $element.StringConstantType -ne [StringConstantType]::BareWord -or
  #|            $element.Value.StartsWith('-')) {
  #|            break
  #|    }
  #|    $element.Value
  #|  }) -join ';'
  #|
  #|  $completions = @(switch ($command) {
  #|    'rg' {
  #|!FLAGS!
  #|    }
  #|  })
  #|
  #|  $completions.Where{ $_.CompletionText -like "$wordToComplete*" } |
  #|    Sort-Object -Property ListItemText
  #|}
  #|

///|
pub fn generate_complete_powershell() -> String {
  let flags = StringBuilder()
  let template = (dash_name : String, name : String, doc : String) => {
    "[CompletionResult]::new('\{dash_name}', '\{name}', [CompletionResultType]::ParameterName, '\{doc}')"
  }
  for i, flag in flag_defs {
    let doc = flag.doc_short.replace_all(old="'", new="''")
    if i > 0 {
      flags.write_char('\n')
    }
    flags.write_string("      ")
    flags.write_string(template("--\{flag.name_long}", flag.name_long, doc))
    if flag.name_short is Some(c) {
      flags.write_string("\n      ")
      flags.write_string(template("-\{c}", c.to_string(), doc))
    }
    if flag.name_negated is Some(n) {
      flags.write_string("\n      ")
      flags.write_string(template("--\{n}", n, doc))
    }
  }
  powershell_template
  .trim_start()
  .to_owned()
  .replace_all(old="!FLAGS!", new=flags.to_string())
}
