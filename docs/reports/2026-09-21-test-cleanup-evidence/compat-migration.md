# Compatibility source migration

Every declaration below moved within the same package. Its assertions and Native execution remain intact; these are not replaced by Wasm or library tests.

The final dispatch function `run_compat_suite` was replaced by the explicit
registrations in `tests/runner/cohorts.mbt`. The sixteen compatibility functions
still run once in a complete Native compat invocation; GNU and stress have
independent registrations. The function-dispatch wrapper carried no assertions.
Filtering a cohort runs its entire multi-command assertion group; group reports
do not certify individual parameter coverage. Further conversion of these
retained procedural groups is intentionally not counted as completed per-command
JSON migration.

| Declaration | Retained file |
| --- | --- |
| fn compat_fail(message : String, failures : Array[String]) -> Unit { | tests/runner/compat.mbt |
| async fn check_catalog( | tests/runner/compat.mbt |
| async fn expect( | tests/runner/compat.mbt |
| async fn expect_case( | tests/runner/compat.mbt |
| async fn expect_stdout_contains( | tests/runner/compat.mbt |
| async fn expect_failure( | tests/runner/compat.mbt |
| async fn run_tail_follow_process( | tests/runner/compat.mbt |
| fn record_tail_follow_result( | tests/runner/compat.mbt |
| async fn run_tail_follow_cases( | tests/runner/compat_filesystem.mbt |
| async fn run_catalog_smoke(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_catalog.mbt |
| async fn run_option_boundaries( | tests/runner/compat_catalog.mbt |
| async fn run_environment_boundary_cases( | tests/runner/compat.mbt |
| async fn run_filesystem_cases( | tests/runner/compat_filesystem.mbt |
| fn record_result( | tests/runner/compat.mbt |
| fn patterned_bytes(length : Int) -> Bytes { | tests/runner/compat_text.mbt |
| async fn expect_round_trip( | tests/runner/compat.mbt |
| async fn run_chunk_boundary_cases( | tests/runner/compat.mbt |
| async fn run_merge_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat.mbt |
| async fn run_record_file_cases( | tests/runner/compat_text.mbt |
| async fn run_shell_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_shell.mbt |
| async fn run_text_option_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_text.mbt |
| async fn run_edge_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_text.mbt |
| async fn run_stdin_prompt_cases( | tests/runner/compat_process.mbt |
| async fn run_argument_edge_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_text.mbt |
| async fn run_http_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_network.mbt |
| async fn run_https_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_network.mbt |
| async fn run_connect_proxy( | tests/runner/compat_network.mbt |
| async fn run_proxy_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_network.mbt |
| async fn run_stress_cases(bin_root : String, failures : Array[String]) -> Unit { | tests/runner/compat_stress.mbt |
| async fn compare_gnu( | tests/runner/compat_gnu.mbt |
| async fn compare_gnu_tail_follow( | tests/runner/compat_gnu.mbt |
| async fn run_gnu_differential( | tests/runner/compat_gnu.mbt |
| async fn run_compat_suite( | tests/runner/compat.mbt |
