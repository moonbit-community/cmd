///|
fn windows_mv_scenario(id : String) -> Bool {
  @mv_scenarios.supports(id)
}

///|
async fn windows_mv_links_scenario(
  root : String,
  _wasm : Bool,
  work : String,
) -> Unit {
  @mv_scenarios.run(
    {
      program: @testkit.command_program(),
      prefix: @testkit.command_args(root, "mv", []),
      source_version: "workspace",
      published: @testkit.published_mode(),
    },
    work,
  )
}
