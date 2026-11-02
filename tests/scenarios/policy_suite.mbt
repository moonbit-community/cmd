///|
async fn run_policy_suite(
  root : String,
  wasm_root : String,
  failures : Array[String],
) -> Unit {
  policy_wasm_root.val = wasm_root
  check_admission(root, failures)
  check_runtime_policy(root, failures)
  check_mutation_policy(root, failures)
  check_process_and_network_policy(root, failures)
  check_allowed_network_policy(root, failures)
  check_chmod_policy(root, failures)
}
