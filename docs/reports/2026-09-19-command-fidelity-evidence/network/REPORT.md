# Published cli/curl, cli/wget and cli/jq invocation audit

Date: 2026-09-19. Source interpretation uses HEAD `8b79e9b`; product source was unchanged. Language revision: 2026-10-11; historical observations retained.

Every candidate ran through `moonx cli/<cmd> ...` without `--experimental-policy`. `moonx -v` showed the local registry index resolving all three commands to 0.1.4 and executing cached Wasm assets. No `@latest` query was made; this does not establish the remote registry's latest version. Oracles were local curl 8.7.1, GNU Wget 1.25.0 and jq 1.7.1-apple.

Requests used only the probe's `127.0.0.1` HTTP fixture. Child proxy variables were empty and `NO_PROXY=*`; the fixture was canceled and closed on completion. The main probe had 20 cases, followed by three targeted jq cases after source review identified parsing and substitution problems. Of 23 cases, 14 matched native stdout and status and nine differed functionally. Curl's HTTP 404 case returned 22 on both sides but differed in stderr; 13 cases therefore matched all three observations byte-for-byte. These are selected-case counts, not command coverage percentages.

## Findings

1. **Ordinary jq input sequences and slurp were incompatible.** For `true\nfalse\n`, `moonx cli/jq -e .` returned 5 with empty stdout and `Invalid character 'f' at line 2, column 0`; native jq printed two lines and returned 1. For `1 2 {"a":3}\n`, `-c .` returned 5 instead of three values and status 0. For `1\n2\n`, `-sc .` returned 5 instead of `[1,2]\n`. These are default input semantics, not `--stream`. At `commands/jq/main_native.mbt:312`, the whole stdin/file was parsed once with `@json.parse(input)`; the slurp branch at line 454 likewise parsed each file as one JSON value. Evidence: `18-*`, `19-*`, `21-*`.

2. **jq `--arg` used text substitution rather than variable binding.** `moonx cli/jq -nr --arg name Moon '"hello \($name)"'` returned 5 with an undefined-variable error instead of `hello Moon\n`. `moonx cli/jq -nc --arg x outer '"inner" as $x | $x'` returned 3 with `Expected variable after 'as'` instead of `"inner"\n`. `substitute_arguments` at `commands/jq/main_native.mbt:54` skipped strings at line 73 and replaced local binding names outside strings with JSON literals at line 81; line 415 sent the altered text to the evaluator. Evidence: `22-*`, `23-*`.

3. **Common curl/wget authentication and cookie options were unimplemented, not rejected by runtime policy.** Curl `-sS -u u:p URL/auth` and `-b sid=one URL/cookie` failed option parsing with status 2; native curl returned `auth-ok\n` and `sid=one\n`, respectively, with status 0. Wget `-qO- --user=u --password=p URL/auth` and `--save-cookies FILE URL/cookie` similarly returned 2 for unknown options, while native wget returned 0. Option tables were at `commands/curl/options.mbt:211` and `commands/wget/options.mbt:150`. `docs/compatibility.md:107` and line 145 explicitly excluded auth/cookie state, so these were declared gaps that still prevented unchanged command-line migration. Evidence: `04-*`, `05-*`, `10-*`, `11-*`.

4. **The gaps did not prohibit authentication or connectivity.** Against the same fixture and without policy arguments, curl `-H 'Authorization: Basic dTpw'` and URL userinfo `http://u:p@127.0.0.1:PORT/auth` both produced `auth-ok\n`, status 0, matching native curl. `core/netops/transfer.mbt:170` generated Basic Authorization from URL userinfo. No policy relaxation was needed; CLI semantics were missing. Evidence: `06-*`, `12-*`.

## Observed passing behavior

- curl GET, relative redirects with `-L`, `-f` HTTP 404 status 22, explicit Authorization headers and URL-userinfo Basic authentication.
- wget GET, default relative redirects and HTTP 404 status 8.
- jq `map(. + 1)`, `.[] | select(. > 1)`, `reduce .[] as $x (0; . + $x)`, `.items |= map(. + 1)`, negative array indices and `to_entries | map(.value)`, each with one JSON input.

## Reproduction and evidence

`moon run /tmp/cmd-audit-20260919/network/probe.mbtx` recreates the HTTP fixture and 20 cases; `moon run /tmp/cmd-audit-20260919/network/jq-followup.mbtx` reruns the three additional jq cases. The main probe replaces its results; the follow-up appends to `followup.jsonl`. Copy the evidence directory before rerunning if the original results must be retained.

The first JSONL files accidentally retained only their last records because append mode was combined with default CreateOrTruncate. Separately saved `.stdout`, `.stderr` and `.status` files were unaffected. The probe was corrected to `create_mode=@fs.OpenOrCreate, append=true`. `recover-evidence.mbtx` rebuilt complete JSONL from 156 preserved raw output files without rerunning commands or adding cases. Argv and stdin came from original case definitions; the dynamic address came from the preserved `fixture-url.txt`. Every reconstructed record identifies provenance and source paths.

Recovered `results.jsonl` has 46 invocations: six version/resolution records and 20 comparison pairs. `followup.jsonl` has six invocations, or three pairs. Truncated originals remain as `results.jsonl.truncated-original` and `followup.jsonl.truncated-original`. `recovery-summary.json` records recovery counts and comparisons recomputed from raw output, with script assertions. `MANIFEST.txt` lists archival evidence without `_build` caches.

`*-resolution.stderr` records resolved versions and asset paths; `*-version.stdout` records oracle versions. The recorded fixture URL is inactive; rerunning allocates a new port. This audit did not verify public HTTPS, TLS certificates, HTTP/2, concurrency or other platforms, and did not treat README claims as execution evidence. The extra `jq -l` log mode skips invalid lines; its existence does not establish default jq input-sequence compatibility.
