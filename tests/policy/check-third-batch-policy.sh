#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
policy_dir="$root_dir/tests/policy"

run_moon() {
  moon "$@"
}

expect_process_denied() {
  command_name=$1
  output_file=$2
  stdout_file=$3
  shift 3
  if run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    "$command_name" -- "$@" >"$stdout_file" 2>"$output_file"; then
    printf '%s\n' "expected process policy to reject $command_name" >&2
    exit 1
  fi
  # The runtime and guest may write denial diagnostics concurrently. Assert
  # the policy-visible effects instead of relying on an exact stderr ordering.
  test -s "$output_file"
  test ! -s "$stdout_file"
}

expect_network_denied() {
  command_name=$1
  output_file=$2
  shift 2
  if run_moon run --target wasm --wasm-policy "$policy_dir/net-deny.json" \
    "$command_name" -- "$@" >"$output_file" 2>&1; then
    printf '%s\n' "expected network policy to reject $command_name" >&2
    exit 1
  fi
  grep -q -E 'Permission denied|OSError' "$output_file"
}

check_package_admission() {
  while IFS= read -r command_name; do
    test -n "$command_name"
    test -f "$root_dir/$command_name/moon.pkg"
    grep -q 'supported_targets = "native+wasm"' \
      "$root_dir/$command_name/moon.pkg"
    if grep -R -n -E 'spawn_orphan|"/bin/(sh|make|curl|wget)"' \
      "$root_dir/$command_name"; then
      printf '%s\n' "unsafe direct host path in $command_name" >&2
      exit 1
    fi
    if grep -qx "$command_name" "$policy_dir/allow-list.txt"; then
      printf '%s\n' "$command_name must not enter the default allow-list yet" >&2
      exit 1
    fi
    case "$command_name" in
      env|xargs|timeout)
        grep -q '"moonbitlang/async/process"' \
          "$root_dir/$command_name/moon.pkg"
        ;;
      sh|make)
        grep -q '"mooxCLI/cmd/internal/shell"' \
          "$root_dir/$command_name/moon.pkg"
        ;;
      *)
        if grep -R -n -E '"moonbitlang/async/process"|@process' \
          "$root_dir/$command_name"; then
          printf '%s\n' \
            "$command_name must not acquire child-process authority" >&2
          exit 1
        fi
        ;;
    esac
  done < "$policy_dir/third-batch.txt"
}

check_process_policy() {
  output_file=$1
  run_moon run --target wasm --wasm-policy "$policy_dir/process-echo.json" \
    env -i echo process-policy-ok >"$output_file"
  grep -qx 'process-policy-ok' "$output_file"

  printf '%s\n' one two | run_moon run --target wasm \
    --wasm-policy "$policy_dir/process-echo.json" xargs -n 1 echo \
    >"$output_file"
  grep -qx 'one' "$output_file"
  grep -qx 'two' "$output_file"

  run_moon run --target wasm --wasm-policy "$policy_dir/process-echo.json" \
    timeout -- 1s echo timeout-policy-ok >"$output_file"
  grep -qx 'timeout-policy-ok' "$output_file"

  run_moon run --target wasm --wasm-policy "$policy_dir/process-printf.json" \
    sh -- -c 'printf policy-shell-ok' >"$output_file"
  grep -qx 'policy-shell-ok' "$output_file"

  run_moon run --target wasm --wasm-policy "$policy_dir/process-printf.json" \
    make -- -s -f "$policy_dir/Makefile.third" >"$output_file"
  grep -qx 'policy-make-ok' "$output_file"
}

check_chmod_policy() {
  fixture="$policy_dir/chmod-third-fixture.$$"
  printf '%s\n' policy-mode >"$fixture"
  original_mode=$(mode_of "$fixture")
  if run_moon run --target wasm --wasm-policy "$policy_dir/read-workspace.json" \
    chmod -- 600 "$fixture" >"$denied_output" 2>&1; then
    printf '%s\n' 'expected read-only policy to reject chmod' >&2
    exit 1
  fi
  grep -q 'Permission denied' "$denied_output"
  test "$(mode_of "$fixture")" = "$original_mode"
  rm -f "$fixture"
}

mode_of() {
  case "$(uname -s)" in
    Darwin) stat -f '%Lp' "$1" ;;
    *) stat -c '%a' "$1" ;;
  esac
}

main() {
  denied_output=$(mktemp "${TMPDIR:-/tmp}/mooncmd-third-denied.XXXXXX")
  allowed_output=$(mktemp "${TMPDIR:-/tmp}/mooncmd-third-allowed.XXXXXX")
  trap 'rm -f "$denied_output" "$allowed_output" "$policy_dir/wget-third-output" "$policy_dir/chmod-third-fixture.$$"' EXIT HUP INT TERM
  check_package_admission
  expect_process_denied env "$denied_output" "$allowed_output" -i echo denied
  if printf '%s\n' denied | run_moon run --target wasm \
    --wasm-policy "$policy_dir/read-workspace.json" xargs -n 1 echo \
    >"$allowed_output" 2>"$denied_output"; then
    printf '%s\n' 'expected process policy to reject xargs' >&2
    exit 1
  fi
  test -s "$denied_output"
  test ! -s "$allowed_output"
  expect_process_denied timeout "$denied_output" "$allowed_output" 1s echo denied
  check_process_policy "$allowed_output"
  expect_process_denied sh "$denied_output" "$allowed_output" -c 'printf denied'
  expect_process_denied make "$denied_output" "$allowed_output" -s -f \
    "$policy_dir/Makefile.third"
  expect_network_denied curl "$denied_output" http://127.0.0.1:1/
  expect_network_denied wget "$denied_output" http://127.0.0.1:1/
  check_chmod_policy
  printf '%s\n' 'Third-batch policy smoke tests passed.'
}

main "$@"
