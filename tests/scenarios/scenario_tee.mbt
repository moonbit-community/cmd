///|
async fn tee_modes_scenario(
  root : String,
  work : String,
  default_only : Bool,
  oracle_image? : String,
) -> Unit {
  @filesystem.check_tee_modes(
    @harness.command_program(),
    @harness.command_args(root, "tee", []),
    work,
    default_only~,
  )
  if oracle_image is Some(image) {
    @filesystem.check_tee_oracle(work + "/oracle", image)
  }
}
