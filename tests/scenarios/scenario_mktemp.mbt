///|
async fn mktemp_options_scenario(
  root : String,
  work : String,
  check_mode : Bool,
  oracle_image? : String,
  proof? : @harness.ScenarioProof,
) -> Unit {
  @filesystem.check_mktemp_options(
    work,
    (args, cwd, environment) => {
      scenario_run(work, root, "mktemp", args, cwd~, extra_env=environment)
    },
    check_mode~,
    proof?,
  )
  if oracle_image is Some(image) {
    @filesystem.check_mktemp_oracle(work + "/oracle", image)
  }
}
