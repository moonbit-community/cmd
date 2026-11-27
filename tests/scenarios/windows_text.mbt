///|
async fn windows_text_scenario(
  root : String,
  command : String,
  work : String,
) -> Unit {
  let program = if command == "rg" {
    @env.get_env_var("CMD_WINDOWS_RG").unwrap_or("rg.exe")
  } else {
    "C:/msys64/usr/bin/" + command + ".exe"
  }
  let version = @harness.run(program, ["--version"], cwd=work)
  @fs.write_file(work + "/oracle-version.txt", version.stdout)
  assert_eq(version.status, 0)
  let marker = match command {
    "cat" => "GNU coreutils"
    "grep" => "GNU grep"
    "diff" => "GNU diffutils) 3.12"
    _ => "ripgrep 15.1.0"
  }
  assert_true(@harness.scenario_text(version.stdout).contains(marker))
  let input = if command == "diff" {
    b"NUL\x00\r\nTAG\ninvalid\xff\rX\x1aAFTER\r\nOLD\r\n"
  } else {
    b"NUL\x00\r\nTAG\r\nTAG\ninvalid\xffTAG\rX\x1aAFTER\r\n"
  }
  @fs.write_file(work + "/payload", input)
  if command == "diff" {
    @fs.write_file(
      work + "/peer",
      b"NUL\x00\nTAG\ninvalid\xff\rX\x1aAFTER\nNEW\n",
    )
  }
  let modes : Array[(String, Array[String], Int32)] = match command {
    "cat" => [("raw", [], 0), ("ends", ["-E"], 0)]
    "grep" =>
      [
        ("text", ["-a", "TAG"], 0),
        ("without-match", ["--binary-files=without-match", "AFTER"], 1),
        ("quiet-binary", ["--binary-files=binary", "-q", "AFTER"], 0),
      ]
    "diff" => [("strip", ["-a", "--strip-trailing-cr"], 1)]
    _ =>
      [
        ("crlf", ["-a", "--crlf", "TAG$"], 0),
        ("implicit-stdin", ["-a", "--crlf", "TAG$"], 0),
      ]
  }
  let differences = []
  for (label, flags, expected) in modes {
    let sources = if label == "implicit-stdin" {
      ["redirect", "pipe"]
    } else {
      ["file", "redirect", "pipe"]
    }
    for source in sources {
      let args = if command == "diff" {
        [..flags, if source == "file" { "payload" } else { "-" }, "peer"]
      } else if source == "file" {
        [..flags, "payload"]
      } else if command == "rg" && label == "crlf" {
        [..flags, "-"]
      } else {
        flags
      }
      let id = label + "-" + source
      let reference = windows_byte_observe(
        program,
        args,
        source,
        work,
        work + "/oracle-" + id,
        input,
      )
      let candidate = windows_byte_observe(
        @harness.command_program(),
        @harness.command_args(root, command, args),
        source,
        work,
        work + "/wasm-" + id,
        input,
      )
      let agrees = if label == "implicit-stdin" {
        reference.stdout == b"TAG\r\nTAG\ninvalid\xffTAG\rX\x1aAFTER\r\n" &&
        candidate.status == 2 &&
        candidate.stdout == b"" &&
        candidate.stderr ==
        b"rg: stdin type detection requires a released public MoonBit API; specify a path or -\n"
      } else {
        candidate.status == reference.status &&
        candidate.stdout == reference.stdout &&
        candidate.stderr == reference.stderr
      }
      if reference.status != expected || reference.stderr != b"" || !agrees {
        differences.push(id)
      }
    }
  }
  assert_eq(differences, [])
}
