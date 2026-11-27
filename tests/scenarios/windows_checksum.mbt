///|
async fn windows_checksum_scenario(
  root : String,
  command : String,
  work : String,
) -> Unit {
  let input = b"A\r\nB\n\xff\x00\rX\x1aAFTER\r\n"
  @fs.write_file(work + "/payload", input)
  // MSYS2 releases also ship older cksum versions without --untagged.
  // Its SHA-256 untagged format is the standalone sha256sum format.
  let oracle_command = if command == "cksum" { "sha256sum" } else { command }
  let oracle = "C:/msys64/usr/bin/" + oracle_command + ".exe"
  let version = @harness.run(oracle, ["--version"], cwd=work)
  @fs.write_file(work + "/oracle-version.txt", version.stdout)
  assert_eq(version.status, 0)
  assert_true(@harness.scenario_text(version.stdout).contains("GNU coreutils"))
  let differences : Array[String] = []
  for
    (mode, flags) in [
      ("default", []),
      ("binary", ["-b"]),
      ("text", ["-t"]),
      ("zero", ["-z"]),
    ] {
    for source in ["file", "redirect", "pipe"] {
      let args = if source == "file" { [..flags, "payload"] } else { flags }
      let label = mode + "-" + source
      let reference = windows_byte_observe(
        oracle,
        args,
        source,
        work,
        work + "/oracle-" + label,
        input,
      )
      let flags = if command == "cksum" {
        ["-a", "sha256", "--untagged", ..args]
      } else {
        args
      }
      let actual = windows_byte_observe(
        @harness.command_program(),
        @harness.command_args(root, command, flags),
        source,
        work,
        work + "/wasm-" + label,
        input,
      )
      if reference.status != 0 ||
        reference.stderr != b"" ||
        actual.status != reference.status ||
        actual.stdout != reference.stdout ||
        actual.stderr != reference.stderr {
        differences.push(label)
      }
    }
  }
  assert_eq(differences, [])
}
