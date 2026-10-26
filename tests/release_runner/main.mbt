///|
async fn main {
  run() catch {
    error => {
      @stdio.stderr.write("release acceptance: " + error.to_string() + "\n")
      @sys.exit(1)
    }
  }
}

///|
async fn run() -> Unit {
  let args = @env.args()[1:]
  if args == ["--generate-candidate"] {
    generate_candidate()
    return
  }
  let mut manifest = "tests/release_runner/current/latest.json"
  let mut suite = "functional"
  let forwarded : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let flag = args[index]
    guard args.get(index + 1) is Some(value) else {
      fail("missing value for " + flag)
    }
    match flag {
      "--manifest" => manifest = value
      "--suite" => suite = value
      "--moonx"
      | "--oracle-image"
      | "--oracle-profile"
      | "--report-dir"
      | "--command"
      | "--case" => forwarded.append([flag, value])
      "--jobs" => {
        guard value == "1" else {
          fail("published acceptance is serial; use --jobs 1")
        }
      }
      _ => fail("unknown option: " + flag)
    }
    index += 2
  }
  guard ["functional", "smoke", "oracle", "differential", "all", "validate"].contains(
    suite,
  ) else {
    fail("unknown suite: " + suite)
  }
  let driver = @fs.realpath(
    "_build/native/release/build/mooxCLI/cmd-tests/runner/runner.exe",
  )
  let arguments = [
    "--published-manifest",
    @fs.realpath(manifest),
    "--jobs",
    "1",
    ..forwarded,
  ]
  if suite == "validate" {
    arguments.append(["--suite", "functional", "--validate-only"])
  } else {
    arguments.append([
      "--suite",
      match suite {
        "smoke" => "functional"
        "differential" => "oracle"
        _ => suite
      },
    ])
  }
  @shell.Cmd(driver, arguments, stdout=Inherit, stderr=Inherit).run()
}
