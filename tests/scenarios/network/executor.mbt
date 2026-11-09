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
  run : @harness.TimedRun
  source_version : String
  program : String
  args : Array[String]
  infrastructure_error : String?
  retain_identity : Bool
}

///|
pub(all) struct Executor {
  invoke : async (Invocation) -> Execution
  proof : @harness.ScenarioProof?
}

///|
pub fn supports(id : String) -> Bool {
  [
    "network-auth-cookie", "network-auth-cookie-oracle", "network-transfer-boundaries",
    "network-transfer-boundaries-oracle", "network-cookie-suffix", "network-cookie-suffix-oracle",
    "network-idna", "network-idna-oracle", "network-wget-cookies", "network-wget-cookies-oracle",
    "network-wget-authentication", "network-wget-authentication-oracle", "network-wget-cookie-expiry",
    "network-wget-cookie-expiry-oracle", "network-wget-cookie-dates", "network-wget-cookie-dates-oracle",
    "network-curl-cookie-domains", "network-curl-cookie-domains-oracle", "network-wget-cookie-domains",
    "network-wget-cookie-domains-oracle", "network-curl-cookie-lifecycle", "network-curl-cookie-lifecycle-oracle",
    "network-curl-http-retry", "network-curl-http-retry-oracle",
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
    "network-curl-cookie-lifecycle" | "network-curl-cookie-lifecycle-oracle" =>
      network_curl_transfers_scenario(
        executor,
        work,
        corpus="curl-cookie-lifecycle",
        oracle_image?,
      )
    "network-curl-http-retry" | "network-curl-http-retry-oracle" =>
      network_curl_transfers_scenario(
        executor,
        work,
        corpus="curl-http-retry",
        oracle_image?,
      )
    "network-curl-cookie-domains" | "network-curl-cookie-domains-oracle" =>
      network_cookie_domains_scenario(
        executor,
        work,
        tool="curl",
        oracle_image?,
      )
    "network-wget-cookie-domains" | "network-wget-cookie-domains-oracle" =>
      network_cookie_domains_scenario(
        executor,
        work,
        tool="wget",
        oracle_image?,
      )
    "network-auth-cookie" | "network-auth-cookie-oracle" =>
      network_cli_scenario(executor, work, oracle_image?)
    "network-transfer-boundaries" | "network-transfer-boundaries-oracle" =>
      network_transfer_scenario(executor, work, oracle_image?)
    "network-cookie-suffix" | "network-cookie-suffix-oracle" => {
      let failures : Array[String] = []
      network_cookie_suffix_scenario(executor, work, failures, oracle_image?)
      guard failures.is_empty() else { fail(failures.join("\n")) }
    }
    "network-idna" | "network-idna-oracle" =>
      network_idna_scenario(executor, work, oracle_image?)
    "network-wget-cookies" | "network-wget-cookies-oracle" =>
      network_wget_cookies_scenario(executor, work, oracle_image?)
    "network-wget-cookie-expiry" | "network-wget-cookie-expiry-oracle" =>
      network_wget_cookies_scenario(
        executor,
        work,
        oracle_image?,
        corpus="wget-cookie-expiry",
      )
    "network-wget-cookie-dates" | "network-wget-cookie-dates-oracle" =>
      network_wget_cookies_scenario(
        executor,
        work,
        oracle_image?,
        corpus="wget-cookie-dates",
      )
    "network-wget-authentication" | "network-wget-authentication-oracle" =>
      network_wget_authentication_scenario(executor, work, oracle_image?)
    _ => fail("unknown shared network scenario: " + id)
  }
}

///|
/// These dimensions come from the shared assertions, not from an empty JSON
/// case's availability contract. The lifecycle and retry corpora compare full
/// file bytes; older Cookie scenarios compare logical jar rows.
pub fn observations(id : String) -> Array[String] {
  if !supports(id) {
    return []
  }
  let result = [
    "status", "stdout", "stdout-bytes", "stderr", "stderr-bytes", "content", "file-content",
  ]
  if id.has_prefix("network-curl-cookie-lifecycle") ||
    id.has_prefix("network-curl-http-retry") {
    result.append([
      "type", "file-type", "request-count", "request-target", "request-host", "request-cookie",
      "pre-response-file-state", "cookie-effects",
    ])
  } else if id.has_prefix("network-transfer-boundaries") {
    result.append([
      "type", "file-type", "request-method", "request-target", "request-body", "request-cookie",
      "request-range", "pre-response-file-state",
    ])
  } else {
    result.append(["request-count", "request-authorization", "cookie-effects"])
    if id.has_prefix("network-idna") {
      result.push("request-target")
    }
    if id.has_prefix("network-wget-authentication") {
      result.append(["request-method", "request-target", "request-body"])
    }
    if id.contains("cookie-domains") {
      result.append(["request-target", "request-host", "cookie-row-order"])
    }
    if !(@async.platform is Windows) &&
      !id.has_prefix("network-wget-") &&
      !id.contains("cookie-domains") {
      result.push("mode")
    }
  }
  result
}
