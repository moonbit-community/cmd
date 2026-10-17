///|
/// Normalize only the decoded arguments in a harness-authored request record.
/// Windows roots are JSON-escaped on disk; raw product captures are unchanged.
fn scenario_request_pair_bytes(
  data : Bytes,
  work : String,
  origin : String?,
  filesystem_root? : String,
) -> Bytes raise {
  let request = @json.parse(@utf8.decode(data))
  guard request is Object(fields) &&
    fields.get("command") is Some(String(_)) &&
    fields.get("args") is Some(Array(arguments)) else {
    fail("invalid scenario request record")
  }
  fields["args"] = Json::array(
    arguments.map(argument => {
      guard argument is String(value) else {
        fail("non-string scenario request argument")
      }
      Json::string(
        @utf8.decode(
          scenario_pair_bytes(
            @utf8.encode(value),
            work,
            origin,
            filesystem_root?,
          ),
        ),
      )
    }),
  )
  @utf8.encode(@testkit.canonical_json(request))
}
