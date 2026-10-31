///|
async fn mktemp_options_scenario(
  root : String,
  wasm : Bool,
  work : String,
  check_mode : Bool,
  oracle_image? : String,
  proof? : @testkit.ScenarioProof,
) -> Unit {
  @testkit.check_mktemp_options(
    work,
    (args, cwd, environment) => {
      scenario_run(
        work,
        root,
        wasm,
        "mktemp",
        args,
        cwd~,
        extra_env=environment,
      )
    },
    check_mode~,
    proof?,
  )
  if oracle_image is Some(image) {
    @testkit.check_mktemp_oracle(work + "/oracle", image)
  }
}
