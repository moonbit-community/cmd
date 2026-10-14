///|
async fn main {
  match @env.args()[1:] {
    ["refresh"] => @registry.refresh_workspace_registry()
    ["strengthen-backend-pairs"] =>
      @registry.strengthen_workspace_backend_pairs()
    ["migrate-release-metadata"] =>
      @registry.migrate_workspace_release_metadata()
    _ =>
      fail(
        "Usage: registry refresh|strengthen-backend-pairs|migrate-release-metadata",
      )
  }
}
