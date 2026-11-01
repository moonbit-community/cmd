///|
fn windows_mv_scenario(id : String) -> Bool {
  @filesystem.supports(id)
}

///|
async fn windows_mv_links_scenario(root : String, work : String) -> Unit {
  @filesystem.run(
    {
      program: @harness.command_program(),
      prefix: @harness.command_args(root, "mv", []),
      source_version: "workspace",
      published: @harness.published_mode(),
    },
    work,
  )
}
