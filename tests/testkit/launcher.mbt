///|
/// One driver invocation selects one delivery mode. Published commands and
/// their children resolve through the same explicit version inventory.
let published_commands : Map[String, String] = Map([])

///|
let command_launcher : Ref[String] = Ref("moonrun")

///|
pub fn configure_commands(
  coordinates : Map[String, String],
  launcher : String,
) -> Unit {
  published_commands.clear()
  for name, coordinate in coordinates {
    published_commands[name] = coordinate
  }
  command_launcher.val = launcher
}

///|
pub fn published_mode() -> Bool {
  !published_commands.is_empty()
}

///|
pub fn command_available(name : String) -> Bool {
  !published_mode() || published_commands.contains(name)
}

///|
pub fn command_version(name : String) -> String? {
  published_commands
  .get(name)
  .map(coordinate => coordinate.split("@").last().unwrap().to_owned())
}

///|
pub fn command_program() -> String {
  command_launcher.val
}

///|
pub fn command_args(
  root : String,
  name : String,
  args : Array[String],
  policy? : String,
) -> Array[String] raise {
  if published_mode() {
    guard published_commands.get(name) is Some(coordinate) else {
      fail("command has no selected published coordinate: " + name)
    }
    match policy {
      Some(path) => ["--experimental-policy", path, coordinate, "--", ..args]
      None => [coordinate, "--", ..args]
    }
  } else {
    match policy {
      Some(path) => ["--policy", path, wasm_path(root, name), "--", ..args]
      None => [wasm_path(root, name), "--", ..args]
    }
  }
}

///|
pub fn command_line(
  root : String,
  name : String,
  args : Array[String],
) -> Array[String] raise {
  [command_program(), ..command_args(root, name, args)]
}

///|
pub async fn run_command(
  root : String,
  name : String,
  args : Array[String],
  stdin? : Bytes,
  cwd? : String,
  extra_env~ : Map[String, String] = Map([]),
) -> RunResult {
  run(
    command_program(),
    command_args(root, name, args),
    stdin?,
    cwd?,
    extra_env~,
  )
}
