///|
let process_starts : Map[String, Int32] = Map([])

///|
let container_starts : Ref[Int32] = Ref(0)

///|
let owned_oracle_invocations : Ref[Int32] = Ref(0)

///|
pub async fn[T] spawn(
  group : @async.TaskGroup[T],
  program : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String],
  inherit_env? : Bool,
  stdin? : &@process.ProcessInput,
  stdout? : &@process.ProcessOutput,
  stderr? : &@process.ProcessOutput,
  cwd? : StringView,
  no_console_window? : Bool,
  cancel_handler? : @process.CancellationHandler,
  no_wait? : Bool,
) -> @process.Process {
  let child = @process.spawn(
    group,
    program,
    args,
    extra_env?,
    inherit_env?,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
    no_console_window?,
    cancel_handler?,
    no_wait?,
  )
  let name = @path.Path(program.to_owned()).basename().to_owned()
  process_starts[name] = process_starts.get(name).unwrap_or(0) + 1
  child
}

///|
pub fn launch_counts() -> Json {
  {
    "process_starts_by_program": @json.to_json(process_starts),
    "oracle_container_starts": container_starts.val,
    "one_shot_oracle_invocations": owned_oracle_invocations.val,
  }
}
