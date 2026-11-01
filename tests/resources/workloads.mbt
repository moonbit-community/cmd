///|
fn arguments(
  command : String,
  input : String,
  changed : String,
  binary : Bool,
) -> Array[String] {
  match command {
    "split" => ["-b", "8M", "-", "part-"]
    "csplit" => ["-s", "-n", "6", "-f", "part-", "-", "/^SECTION /", "{*}"]
    "sort" => ["-S", "4M"]
    "column" => ["-t"]
    "grep" => if binary { ["-a", "-F", "needle"] } else { ["-F", "needle"] }
    "cut" => ["-b", "1-8"]
    "wc" => ["-l"]
    "gzip" => ["-n", "-c"]
    "diff" => ["--label", "left", "--label", "right", "-u", input, changed]
    "strings" => ["-a"]
    _ => []
  }
}

///|
async fn decode(program : String, input : String, output : String) -> Bool {
  let result = @shell.Cmd(
    program,
    ["-d", "-c"],
    stdin=FromFile(input),
    stdout=ToFile(output),
  ).status(timeout_ms=900000)
  result == 0
}
