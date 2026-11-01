///|
pub(all) struct Invocation {
  command : String
  args : Array[String]
  stdin : Bytes
  cwd : String
  environment : Map[String, String]
}

///|
pub(all) struct Execution {
  run : @testkit.TimedRun
  source_version : String
  program : String
  args : Array[String]
  infrastructure_error : String?
  retain_identity : Bool
}

///|
pub(all) struct Executor {
  invoke : async (Invocation) -> Execution
  proof : @testkit.ScenarioProof?
}

///|
pub fn supports(id : String) -> Bool {
  [
    "network-auth-cookie", "network-auth-cookie-oracle", "network-transfer-boundaries",
    "network-transfer-boundaries-oracle",
  ].contains(id)
}

///|
/// Both launch adapters execute these same assertions and retain their raw
/// effects. The caller supplies the artifact identity and oracle preflight.
pub async fn run(
  id : String,
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  match id {
    "network-auth-cookie" | "network-auth-cookie-oracle" =>
      network_cli_scenario(executor, work, oracle_image?)
    "network-transfer-boundaries" | "network-transfer-boundaries-oracle" =>
      network_transfer_scenario(executor, work, oracle_image?)
    _ => fail("unknown shared network scenario: " + id)
  }
}

///|
/// These dimensions come from the shared assertions, not from an empty JSON
/// case's availability contract. Cookie-jar bytes are not compared wholesale.
pub fn observations(id : String) -> Array[String] {
  if !supports(id) {
    return []
  }
  let result = [
    "status", "stdout", "stdout-bytes", "stderr", "stderr-bytes", "content", "file-content",
  ]
  if id.has_prefix("network-transfer-boundaries") {
    result.append([
      "type", "file-type", "request-method", "request-target", "request-body", "request-cookie",
      "request-range", "pre-response-file-state",
    ])
  } else {
    result.append(["request-count", "request-authorization", "cookie-effects"])
    if !(@async.platform is Windows) {
      result.push("mode")
    }
  }
  result
}
