///|
/// Only execution-relevant, non-secret variables enter persisted provenance.
/// Unset variables remain absent, distinct from variables set to an empty value.
pub(all) struct ExecutionEnvironment {
  program : String
  inherit_env : Bool
  values : Map[String, String]
} derive(FromJson, ToJson, @debug.Debug)

///|
let execution_environments : Map[String, ExecutionEnvironment] = Map([])

///|
pub fn begin_environment_capture() -> Unit {
  execution_environments.clear()
}

///|
fn effective_environment(
  program : String,
  inherited : Map[String, String],
  extra : Map[String, String],
  inherit_env : Bool,
) -> ExecutionEnvironment {
  let values : Map[String, String] = Map([])
  for
    name in [
      "LC_ALL", "LANG", "TZ", "TERM", "COLUMNS", "LINES", "NO_COLOR", "POSIXLY_CORRECT",
    ] {
    let value = match extra.get(name) {
      Some(value) => Some(value)
      None => if inherit_env { inherited.get(name) } else { None }
    }
    if value is Some(value) {
      values[name] = value
    }
  }
  { program: @path.Path(program).basename().to_owned(), inherit_env, values, }
}

///|
/// Call at the spawn boundary, using the same options supplied to the child.
/// Program basenames avoid leaking checkout or user directory paths.
pub fn record_execution_environment(
  program : String,
  extra_env~ : Map[String, String] = Map([]),
  inherit_env~ : Bool = true,
) -> Unit {
  let inherited : Map[String, String] = Map([])
  for
    name in [
      "LC_ALL", "LANG", "TZ", "TERM", "COLUMNS", "LINES", "NO_COLOR", "POSIXLY_CORRECT",
    ] {
    if @env.get_env_var(name) is Some(value) {
      inherited[name] = value
    }
  }
  let profile = effective_environment(
    program, inherited, extra_env, inherit_env,
  )
  execution_environments[json_digest(ToJson::to_json(profile))] = profile
}

///|
fn captured_execution_environments() -> Array[ExecutionEnvironment] {
  let keys = execution_environments.keys().collect()
  keys.sort()
  keys.map(key => execution_environments[key])
}

///|
pub fn execution_environment_digest(
  profiles : Array[ExecutionEnvironment],
) -> String {
  let values = profiles.map(profile => canonical_json(ToJson::to_json(profile)))
  values.sort()
  json_digest(Json(values))
}

///|
pub extend ExecutionEnvironment with FromJson::{from_json}

///|
pub extend ExecutionEnvironment with ToJson::{to_json}

///|
pub extend ExecutionEnvironment with @debug.Debug::{to_repr}
