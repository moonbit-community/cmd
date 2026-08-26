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
  grep -q 'Permission denied' "$output_file"
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

check_allow_list() {
  if grep -qx 'jqlog' "$policy_dir/allow-list.txt"; then
    printf '%s\n' 'native-only jqlog must not be in the Wasm allow-list' >&2
    exit 1
  fi

  while IFS= read -r command_name; do
    test -n "$command_name"
    test -f "$root_dir/$command_name/moon.pkg"
    grep -q 'supported_targets = "native+wasm"' \
      "$root_dir/$command_name/moon.pkg"
  done < "$policy_dir/allow-list.txt"

  if grep -R -n -E '"moonbitlang/async/process"|@process' \
    "$root_dir"/base64 "$root_dir"/cat "$root_dir"/comm "$root_dir"/cut \
    "$root_dir"/false "$root_dir"/head "$root_dir"/join "$root_dir"/jq \
    "$root_dir"/nl "$root_dir"/paste "$root_dir"/printf "$root_dir"/sleep \
    "$root_dir"/sort "$root_dir"/tail "$root_dir"/tr "$root_dir"/true \
    "$root_dir"/uniq "$root_dir"/wc "$root_dir"/xxd; then
    printf '%s\n' 'command packages must not delegate to child processes' >&2
    exit 1
  fi
}

main() {
  denied_output=$(mktemp "${TMPDIR:-/tmp}/mooncmd-policy-denied.XXXXXX")
  allowed_output=$(mktemp "${TMPDIR:-/tmp}/mooncmd-policy-allowed.XXXXXX")
  trap 'rm -f "$denied_output" "$allowed_output"' EXIT HUP INT TERM

  check_allow_list
  expect_denied_read "$denied_output"
  expect_allowed_read "$allowed_output"
  printf '%s\n' 'Wasm policy smoke tests passed.'
}

main "$@"
