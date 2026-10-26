///|
fn serial_fixture(fixture : @testkit.Case) -> Bool {
  @testkit.is_network_case(fixture) ||
  fixture.delay_ms.unwrap_or(0) > 0 ||
  fixture.files.any(file => file.atime is Some(_) || file.mtime is Some(_)) ||
  fixture.observe
  .unwrap_or([])
  .any(kind => ["atime", "mtime", "ctime"].contains(kind))
}

///|
async fn run_scheduled_tasks(
  cases : Array[@testkit.Case],
  tasks : Array[async () -> Unit],
  jobs : Int32,
) -> Unit {
  assert_eq(cases.length(), tasks.length())
  let independent : Array[async () -> Unit] = []
  let serial : Array[async () -> Unit] = []
  for index, fixture in cases {
    (if serial_fixture(fixture) { serial } else { independent }).push(
      tasks[index],
    )
  }
  ignore(@async.all(independent, max_concurrent=jobs))
  for task in serial {
    task()
  }
}
