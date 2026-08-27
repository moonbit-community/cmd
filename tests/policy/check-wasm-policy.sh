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

expect_read_only_denial() {
  command_name=$1
  output_file=$2
  shift 2
  if run_moon run --target wasm \
    --wasm-policy "$policy_dir/read-workspace.json" \
    "$command_name" -- "$@" </dev/null >"$output_file" 2>&1; then
    printf '%s\n' "expected read-only policy to reject $command_name" >&2
    exit 1
  fi
  grep -q -E 'Permission denied|IOError|Sandbox policy blocked file write' \
    "$output_file"
}

check_batch2_mutation_policy() {
  fixture_dir=$1
  denied_output=$2
  allowed_output=$3
  policy="$policy_dir/read-write-policy.json"

  mkdir "$fixture_dir/source-dir" "$fixture_dir/empty-dir"
  printf '%s\n' policy-fixture >"$fixture_dir/source"
  printf '%s\n' remove-me >"$fixture_dir/removable"
  printf '%s\n' move-me >"$fixture_dir/movable"

  expect_read_only_denial mkdir "$denied_output" "$fixture_dir/denied-dir"
  expect_read_only_denial touch "$denied_output" "$fixture_dir/denied-touch"
  expect_read_only_denial tee "$denied_output" "$fixture_dir/denied-tee"
  expect_read_only_denial cp "$denied_output" \
    "$fixture_dir/source" "$fixture_dir/denied-copy"
  expect_read_only_denial mv "$denied_output" \
    "$fixture_dir/movable" "$fixture_dir/denied-move"
  expect_read_only_denial rm "$denied_output" "$fixture_dir/removable"
  expect_read_only_denial rmdir "$denied_output" "$fixture_dir/empty-dir"
  expect_read_only_denial ln "$denied_output" \
    -s "$fixture_dir/source" "$fixture_dir/denied-link"

  test ! -e "$fixture_dir/denied-dir"
  test ! -e "$fixture_dir/denied-touch"
  test ! -e "$fixture_dir/denied-tee"
  test ! -e "$fixture_dir/denied-copy"
  test ! -e "$fixture_dir/denied-move"
  test ! -e "$fixture_dir/denied-link"
  test -e "$fixture_dir/movable"
  test -e "$fixture_dir/removable"
  test -d "$fixture_dir/empty-dir"

  run_moon run --target wasm --wasm-policy "$policy" \
    mkdir -- "$fixture_dir/allowed-dir"
  run_moon run --target wasm --wasm-policy "$policy" \
    touch -- "$fixture_dir/allowed-touch"
  printf '%s\n' policy-fixture | run_moon run --target wasm \
    --wasm-policy "$policy" tee -- "$fixture_dir/allowed-tee" \
    >"$allowed_output"
  grep -qx policy-fixture "$allowed_output"
  grep -qx policy-fixture "$fixture_dir/allowed-tee"
  run_moon run --target wasm --wasm-policy "$policy" \
    cp -- "$fixture_dir/source" "$fixture_dir/allowed-copy"
  grep -qx policy-fixture "$fixture_dir/allowed-copy"
  run_moon run --target wasm --wasm-policy "$policy" \
    mv -- "$fixture_dir/movable" "$fixture_dir/allowed-move"
  test ! -e "$fixture_dir/movable"
  grep -qx move-me "$fixture_dir/allowed-move"
  run_moon run --target wasm --wasm-policy "$policy" \
    ln -- -s "$fixture_dir/source" "$fixture_dir/allowed-link"
  test -L "$fixture_dir/allowed-link"
  run_moon run --target wasm --wasm-policy "$policy" \
    rm -- "$fixture_dir/removable"
  test ! -e "$fixture_dir/removable"
  run_moon run --target wasm --wasm-policy "$policy" \
    rmdir -- "$fixture_dir/empty-dir"
  test ! -e "$fixture_dir/empty-dir"
}

check_allow_list() {
  grep -q 'supported_targets = "native+wasm"' \
    "$root_dir/internal/fsops/moon.pkg"
  if grep -R -n -E '"moonbitlang/async/process"|@process' \
    "$root_dir/internal"; then
    printf '%s\n' 'internal command support must not spawn child processes' >&2
    exit 1
  fi
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
  fixture_dir=$(mktemp -d "$policy_dir/write-fixture.XXXXXX")
  trap 'rm -f "$denied_output" "$allowed_output"; rm -rf "$fixture_dir"' \
    EXIT HUP INT TERM

  check_allow_list
  expect_denied_read "$denied_output"
  expect_allowed_read "$allowed_output"
  expect_jqlog_denied_read "$denied_output"
  expect_jqlog_allowed_read "$allowed_output"
  check_batch1_file_policy "$denied_output" "$allowed_output"
  check_batch2_mutation_policy \
    "$fixture_dir" "$denied_output" "$allowed_output"
  printf '%s\n' 'Wasm policy smoke tests passed.'
}

main "$@"
