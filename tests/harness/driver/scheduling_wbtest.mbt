///|
async test "private fixed-time fixtures overlap within the requested limit" {
  let fixture : @harness.Case = @json.from_json({
    "id": "fixed-time",
    "command": "test",
    "args": ["new", "-nt", "old"],
    "files": [
      { "path": "old", "content_text": "old", "mtime": "200001010000.00" },
      { "path": "new", "content_text": "new", "mtime": "202001010000.00" },
    ],
    "environment": {},
    "expected_status": 0,
    "normalizations": [],
  })
  let cases = Array::makei(4, index => { ..fixture, id: "fixed-time-\{index}", })
  for jobs in [1, 2, 4] {
    let active = Ref(0)
    let peak = Ref(0)
    let completed = Ref(0)
    let tasks : Array[async () -> Unit] = cases.map(_ => {
      () => {
        active.val += 1
        peak.val = peak.val.max(active.val)
        @async.sleep(1)
        active.val -= 1
        completed.val += 1
      }
    })
    run_scheduled_tasks(cases, tasks, jobs)
    assert_eq(peak.val, jobs)
    assert_eq(active.val, 0)
    assert_eq(completed.val, cases.length())
  }
}
