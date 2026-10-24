///|
async fn tee_modes_scenario(
  root : String,
  wasm : Bool,
  work : String,
  default_only : Bool,
  oracle_image? : String,
) -> Unit {
  @testkit.check_tee_modes(
    if wasm {
      "moonrun"
    } else {
      @testkit.executable_path(root, "tee")
    },
    if wasm {
      [@testkit.wasm_path(root, "tee"), "--"]
    } else {
      []
    },
    work,
    default_only~,
  )
  if oracle_image is Some(image) {
    @testkit.check_tee_oracle(work + "/oracle", image)
  }
}
