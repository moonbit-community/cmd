///|
priv struct PreparedCorpus {
  source : String
  input : String
}

///|
async fn corpus_observer(
  program : String,
  args : Array[String],
  input : String,
  output : String,
  environment : Map[String, String],
  timeout_ms : Int32,
  receipt_prefix? : String,
) -> Unit {
  let invocation : BenchmarkInvocation = {
    program,
    args,
    stdin_path: input,
    cwd: @path.Path(output).dirname().to_string(),
    environment,
  }
  // This fixed upstream observer is explicitly outside the candidate timing.
  let receipt = receipt_prefix.unwrap_or(output)
  write_json(receipt + ".invocation.json", ToJson::to_json(invocation))
  let observed = measure_invocation(
    invocation,
    output,
    receipt + ".stderr",
    timeout_ms,
  )
  write_json(receipt + ".observation.json", ToJson::to_json(observed))
  guard observed.status == Some(0) &&
    !observed.timed_out &&
    observed.error is None &&
    finite_positive(observed.elapsed_us) &&
    @fs.file_size(receipt + ".stderr") == 0L else {
    fail("fixed native preparation observation failed: " + output)
  }
}
