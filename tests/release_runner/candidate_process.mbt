///|
/// The process boundary receives the fully expanded MoonX invocation. Keeping
/// the boundary injectable lets lifecycle tests drive the real fixture,
/// classification, cleanup and report paths without a registry outage.
priv struct CandidateInvocation {
  program : String
  args : Array[String]
  timeout_ms : Int32
  stdin : Bytes
  cwd : String
  environment : Map[String, String]
}

///|
async fn execute_candidate_process(
  invocation : CandidateInvocation,
) -> @testkit.TimedRun {
  @testkit.run_with_deadline(
    invocation.program,
    invocation.args,
    invocation.timeout_ms,
    stdin=invocation.stdin,
    cwd=invocation.cwd,
    extra_env=invocation.environment,
    inherit_env=true,
  )
}
