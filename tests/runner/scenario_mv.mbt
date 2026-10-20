///|
fn windows_mv_scenario(id : String) -> Bool {
  @mv_scenarios.supports(id)
}

///|
fn windows_mv_scenario_backend(id : String, wasm : Bool) -> Bool {
  @mv_scenarios.backend_selected(id, wasm)
}

///|
async fn windows_mv_links_scenario(
  root : String,
  wasm : Bool,
  work : String,
) -> Unit {
  @mv_scenarios.run(
    {
      program: if wasm {
        "moonrun"
      } else {
        @testkit.executable_path(root, "mv")
      },
      prefix: if wasm {
        [@testkit.wasm_path(root, "mv"), "--"]
      } else {
        []
      },
      source_version: "workspace",
      published: false,
    },
    wasm,
    work,
  )
}
