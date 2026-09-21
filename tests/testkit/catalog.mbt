///|
/// Read both frozen schema 1 manifests and schema 2 per-command collections.
pub async fn load_cases(path : String) -> Array[Case] {
  let value = @json.parse(@fs.read_file(path).text())
  let cases : Array[Case] = match value {
    { "cases": cases, .. } => @json.from_json(cases)
    _ => []
  }
  if value is { "case_files": Array(files), .. } {
    for file in files {
      guard file is String(file) else { fail("case_files must contain paths") }
      let source = @path.Path(path).dirname().join(Path(file)).to_string()
      let contents = @json.parse(@fs.read_file(source).text())
      guard contents is { "cases": selected, .. } else {
        fail("missing cases: \{source}")
      }
      let selected : Array[Case] = @json.from_json(selected)
      cases.append(selected)
    }
  }
  let seen : Map[String, Bool] = Map([])
  for item in cases {
    for id in [item.id, ..item.aliases.unwrap_or([])] {
      if seen.contains(id) {
        fail("duplicate case or alias: \{id}")
      }
      seen[id] = true
    }
  }
  cases
}

///|
pub fn select_cases(
  cases : ArrayView[Case],
  commands : ArrayView[String],
  ids : ArrayView[String],
) -> Array[Case] raise Failure {
  for command in commands {
    if !cases.any(item => {
        item.command == command ||
        item.related_commands.unwrap_or([]).contains(command)
      }) {
      fail("unknown command: \{command}")
    }
  }
  for id in ids {
    if !cases.any(item => {
        item.id == id || item.aliases.unwrap_or([]).contains(id)
      }) {
      fail("unknown case: \{id}")
    }
  }
  let selected = cases.filter(item => {
    (
      commands.is_empty() ||
      commands.contains(item.command) ||
      item.related_commands
      .unwrap_or([])
      .any(command => commands.contains(command))
    ) &&
    (
      ids.is_empty() ||
      ids.contains(item.id) ||
      item.aliases.unwrap_or([]).any(id => ids.contains(id))
    )
  })
  guard !selected.is_empty() else { fail("empty case selection") }
  selected
}

///|
pub fn host_platform() -> String {
  match @async.platform {
    Linux => "linux"
    MacOS => "macos"
    Windows => "windows"
  }
}

///|
pub fn Case::platform_applies(self : Case) -> Bool {
  match self.host_platforms {
    Some(platforms) =>
      platforms.contains(host_platform()) ||
      (platforms.contains("posix") && !(@async.platform is Windows))
    None => true
  }
}

///|
pub async fn run_artifact(
  root : String,
  wasm : Bool,
  command : String,
  args : Array[String],
  stdin? : Bytes,
  cwd? : String,
  extra_env? : Map[String, String] = Map([]),
) -> RunResult {
  let program = if wasm { "moonrun" } else { executable_path(root, command) }
  let args = if wasm { [wasm_path(root, command), "--", ..args] } else { args }
  run(program, args, stdin?, cwd?, extra_env~)
}
