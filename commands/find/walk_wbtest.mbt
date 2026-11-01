///|
fn walk_parser(depth~ : Bool = false, max_depth~ : Int32 = 10) -> FindParser {
  {
    tokens: [],
    pos: 0,
    min_depth: 0,
    max_depth,
    depth_first: depth,
    action: None,
  }
}

///|
async test "find prune and maxdepth avoid directory enumeration" {
  let root = @fs.tmpdir(prefix="mooncmd-find-descent")
  defer @fs.rmdir(root, recursive=true)
  let context : FindContext = {
    now: @fsops.current_timestamp(),
    references: [],
  }
  for
    (parser, expression) in [
      (walk_parser(max_depth=0), Always(false)),
      (walk_parser(), And(Prune, Always(false))),
      (walk_parser(max_depth=0), And(Always(false), Empty)),
    ] {
    assert_false(
      walk_find([root], parser, expression, context, read_directory=_ => {
        fail("this visit must not open the directory")
      }),
    )
  }
}

///|
async test "find postorder enumerates only to descend or evaluate empty" {
  let root = @fs.tmpdir(prefix="mooncmd-find-postorder")
  defer @fs.rmdir(root, recursive=true)
  @fs.write_file(root + "/child", "payload")
  let context : FindContext = {
    now: @fsops.current_timestamp(),
    references: [],
  }
  let calls : Array[String] = []
  assert_false(
    walk_find([root], walk_parser(depth=true), Always(false), context, read_directory=path => {
      calls.push(path)
      @fswalk.read_directory(path)
    }),
  )
  assert_eq(calls, [root])
  calls.clear()
  assert_false(
    walk_find(
      [root],
      walk_parser(max_depth=0),
      And(Empty, Always(false)),
      context,
      read_directory=path => {
        calls.push(path)
        @fswalk.read_directory(path)
      },
    ),
  )
  assert_eq(calls, [root])
}
