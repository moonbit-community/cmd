///|
/// A cancelled direct child is complete only after wait succeeds. Test-boundary
/// injection exercises the same propagation used by the command cohorts.
async fn wait_for_direct_child(
  label : String,
  wait : async () -> Int32,
) -> Unit {
  @async.protect_from_cancel(() => {
    ignore(wait()) catch {
      error =>
        fail("cleanup infrastructure: " + label + ": " + error.to_string())
    }
  })
}
