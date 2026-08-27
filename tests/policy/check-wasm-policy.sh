#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
account_home=${MOON_HOME:-$HOME/.moon-accounts/moonxCLI}
policy_dir="$root_dir/tests/policy"

run_moon() {
  MOON_HOME="$account_home" moon "$@"
}

expect_denied_read() {
  output_file=$1
  if run_moon run --target wasm --wasm-policy "$policy_dir/deny-all.json" \
    cat -- "$policy_dir/input.txt" >"$output_file" 2>&1; then
    printf '%s\n' "expected deny-all policy to reject cat file read" >&2
    exit 1
  fi
  grep -q -E 'Permission denied|IOError' "$output_file"
  if grep -q 'policy-fixture' "$output_file"; then
    printf '%s\n' "deny-all policy leaked file contents" >&2
    exit 1
  fi
}

expect_allowed_read() {
  output_file=$1
  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    cat -- "$policy_dir/input.txt" >"$output_file"
  grep -qx 'policy-fixture' "$output_file"
}

expect_jqlog_denied_read() {
  output_file=$1
  if run_moon run --target wasm --wasm-policy "$policy_dir/deny-all.json" \
    jqlog -- -f "$policy_dir/input.jsonl" '.message' >"$output_file" 2>&1; then
    printf '%s\n' "expected deny-all policy to reject jqlog file read" >&2
    exit 1
  fi
  grep -q -E 'Permission denied|IOError' "$output_file"
  if grep -q 'policy-fixture' "$output_file"; then
    printf '%s\n' "deny-all policy leaked jqlog file contents" >&2
    exit 1
  fi
}

expect_jqlog_allowed_read() {
  output_file=$1
  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    jqlog -- -f "$policy_dir/input.jsonl" '.message' >"$output_file"
  grep -qx '"policy-fixture"' "$output_file"
}

expect_denied_command() {
  command_name=$1
  output_file=$2
  shift 2
  if run_moon run --target wasm --wasm-policy "$policy_dir/deny-all.json" \
    "$command_name" -- "$@" >"$output_file" 2>&1; then
    printf '%s\n' "expected deny-all policy to reject $command_name" >&2
    exit 1
  fi
  if grep -q 'policy-fixture' "$output_file"; then
    printf '%s\n' "deny-all policy leaked contents through $command_name" >&2
    exit 1
  fi
}

check_batch1_file_policy() {
  denied_output=$1
  allowed_output=$2

  expect_denied_command cmp "$denied_output" \
    "$policy_dir/input.txt" "$policy_dir/input.txt"
  expect_denied_command grep "$denied_output" \
    policy-fixture "$policy_dir/input.txt"
  expect_denied_command ls "$denied_output" "$policy_dir"
  expect_denied_command find "$denied_output" "$policy_dir" -maxdepth 0
  expect_denied_command sha256sum "$denied_output" "$policy_dir/input.txt"

  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    cmp -- "$policy_dir/input.txt" "$policy_dir/input.txt"
  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    grep -- policy-fixture "$policy_dir/input.txt" >"$allowed_output"
  grep -qx 'policy-fixture' "$allowed_output"
  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    ls -- "$policy_dir" >"$allowed_output"
  grep -qx 'input.txt' "$allowed_output"
  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    find -- "$policy_dir" -maxdepth 0 >"$allowed_output"
  grep -qx "$policy_dir" "$allowed_output"
  run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    sha256sum -- "$policy_dir/input.txt" >"$allowed_output"
  grep -q 'input.txt' "$allowed_output"
}

check_allow_list() {
  while IFS= read -r command_name; do
    test -n "$command_name"
    test -f "$root_dir/$command_name/moon.pkg"
    grep -q 'supported_targets = "native+wasm"' \
      "$root_dir/$command_name/moon.pkg"
    if grep -R -n -E '"moonbitlang/async/process"|@process' \
      "$root_dir/$command_name"; then
      printf '%s\n' \
        "$command_name must not delegate to child processes" >&2
      exit 1
    fi
  done < "$policy_dir/allow-list.txt"
}

main() {
  denied_output=$(mktemp "${TMPDIR:-/tmp}/mooncmd-policy-denied.XXXXXX")
  allowed_output=$(mktemp "${TMPDIR:-/tmp}/mooncmd-policy-allowed.XXXXXX")
  trap 'rm -f "$denied_output" "$allowed_output"' EXIT HUP INT TERM

  check_allow_list
  expect_denied_read "$denied_output"
  expect_allowed_read "$allowed_output"
  expect_jqlog_denied_read "$denied_output"
  expect_jqlog_allowed_read "$allowed_output"
  check_batch1_file_policy "$denied_output" "$allowed_output"
  printf '%s\n' 'Wasm policy smoke tests passed.'
}

main "$@"
