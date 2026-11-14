///|
fn run_inputs(
  query : String,
  inputs : Array[Json],
) -> (Array[Json], Int32) raise {
  let output : Array[Json] = []
  let mut reads = 0
  for current = @ast.evaluate(@parser.parse(query), null, @ast.Env::new()) {
    match current.step() {
      Done => break (output, reads)
      Yield(value, next) => {
        output.push(value)
        continue next
      }
      Request(Input, advance) => {
        let value = inputs.get(reads)
        reads += 1
        continue advance(Ok(value))
      }
      Request(_, _) => fail("unexpected request")
      Failed(error) => raise error
      Continue(_) => fail("unresolved continuation")
    }
  }
}

///|
test "input suspension preserves filter and value parameters" {
  let (values, reads) = run_inputs("def twice(f): f,f; twice(input)", [1, 2, 3])
  assert_eq(values, [1, 2])
  assert_eq(reads, 2)
  let (values, reads) = run_inputs("def twice($v): $v,$v; twice(input)", [
    1, 2, 3,
  ])
  assert_eq(values, [1, 1])
  assert_eq(reads, 1)
}

///|
test "generator termination leaves the shared cursor at the next unread value" {
  let cases : Array[(String, Array[Json], Int32)] = [
    ("first(inputs), input", [1, 2], 2),
    ("[limit(2;inputs)],input", [Json::array([1, 2]), 3], 3),
    ("limit(0;inputs), input", [1], 1),
    ("any(inputs; . == 2), input", [true, 3], 3),
    ("all(inputs; . < 2), input", [false, 3], 3),
    ("[limit(3;repeat(input))]", [Json::array([1, 2, 3])], 3),
    ("[limit(1;repeat(input|select(.==2)))],input", [Json::array([2]), 3], 3),
    (
      "first(foreach inputs as $x ([]; .+[$x], .+[input])),input",
      [Json::array([1]), 2],
      2,
    ),
    ("input - input", [1], 2),
    (
      "[[(input,input)-input],input]",
      [Json::array([Json::array([1, 2]), 4])],
      4,
    ),
  ]
  for (query, expected, count) in cases {
    let (actual, reads) = run_inputs(query, [1, 2, 3, 4, 5])
    assert_eq(actual, expected)
    assert_eq(reads, count)
  }
}

///|
test "recursive filters retain bounded host stack depth" {
  assert_eq(
    @ast.eval(
      @parser.parse("def f: if .==0 then . else .-1|f end; 10000|f"),
      null,
    ).collect(),
    [Json(0)],
  )
  assert_eq(
    @ast.eval(@parser.parse("[limit(10000;def f:.,(.+1|f);0|f)]|length"), null).collect(),
    [Json(10000)],
  )
}

///|
test "function definitions capture lexical bindings and support recursion" {
  let cases : Array[(String, Array[Json])] = [
    ("1 as $x | def f: $x; 2 as $x | f", [1]),
    ("def f: 1; def g: f; def f: 2; [g,f]", [Json::array([1, 2])]),
    ("def apply(f): 2 as $x | f; 1 as $x | apply($x)", [1]),
    ("def f: 1; def f($x): $x; [f,f(2)]", [Json::array([1, 2])]),
    (
      "def down: ., if . > 0 then .-1|down else empty end; [3|down]",
      [Json::array([3, 2, 1, 0])],
    ),
    ("def outer($x): def inner: $x; inner; outer(7)", [7]),
    ("def length: 9; length", [9]),
    ("def add($x): $x+1; add(4)", [5]),
  ]
  for (query, expected) in cases {
    assert_eq(@ast.eval(@parser.parse(query), null).collect(), expected)
  }
}
