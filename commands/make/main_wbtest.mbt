///|
async test "shell expansion keeps status newline rules and immediate assignment" {
  let variables : Map[String, Variable] = Map([])
  assert_eq(expand("$(shell printf 'a\\nb\\n\\n')", variables, {}, 0), "a b")
  assert_eq(expand("$(shell false)", variables, {}, 0), "")
  assert_eq(expand("$(.SHELLSTATUS)", variables, {}, 0), "1")
  let database : Database = {
    cwd: ".",
    variables,
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    "X := $(shell printf first)\nX += $(shell printf second)\n", database, ".", 0,
  )
  assert_eq(expand("$(X)", variables, {}, 0), "first second")
  parse_makefile(
    "export EXPORTED = yes\nLOCAL = hidden\nOBSERVED := $(shell printf '%s|%s' \"$$EXPORTED\" \"$$LOCAL\")\n",
    database, ".", 0,
  )
  assert_eq(expand("$(OBSERVED)", variables, {}, 0), "yes|")
  let environment = command_environment(database)
  assert_eq(environment.get("EXPORTED"), Some("yes"))
  assert_eq(environment.get("LOCAL"), None)
  parse_makefile(
    "unexport EXPORTED\nHIDDEN := $(shell printf '%s' \"$$EXPORTED\")\n", database,
    ".", 0,
  )
  assert_eq(expand("$(HIDDEN)", variables, {}, 0), "")
}

///|
async test "parallel scheduler deduplicates dependencies and propagates failures" {
  let database : Database = {
    cwd: ".",
    variables: Map([]),
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    ".PHONY: all shared left right\nall: left right\nleft: shared\nright: shared\nshared:\n",
    database, ".", 0,
  )
  let settings : Settings = {
    cwd: ".",
    jobs: 2,
    silent: true,
    dry_run: false,
    always_make: false,
    keep_going: false,
    what_if: Map([]),
  }
  let ready = @semaphore.Semaphore(2)
  let ack = @semaphore.Semaphore(2)
  ready.acquire()
  ready.acquire()
  ack.acquire()
  ack.acquire()
  let events : Array[String] = []
  @async.with_timeout(5000, () => {
    @async.with_task_group(group => {
      let build = group.spawn(() => {
        build_targets(["all"], database, settings, execute=(node, _, _) => {
          events.push(node.target)
          if node.target == "left" || node.target == "right" {
            ready.release()
            ack.acquire()
            events.push(node.target + "-done")
          }
        })
      })
      ready.acquire()
      ready.acquire()
      assert_eq(events[0], "shared")
      assert_eq(events.length(), 3)
      assert_true(events.contains("left"))
      assert_true(events.contains("right"))
      ack.release()
      ack.release()
      build.wait()
      assert_eq(events.filter(event => event == "shared").length(), 1)
      assert_eq(events.last(), Some("all"))
    })
  })
  parse_makefile("broken:\nafter: broken\nindependent:\n", database, ".", 0)
  for keep_going in [false, true] {
    let visited : Array[String] = []
    try
      build_targets(
        ["after", "independent"],
        database,
        { ..settings, jobs: 1, keep_going, },
        execute=(node, _, _) => {
          visited.push(node.target)
          if node.target == "broken" {
            raise MakeError("fixture failure")
          }
        },
      )
    catch {
      _ => ()
    } noraise {
      _ => fail("failed prerequisite was reported as success")
    }
    assert_false(visited.contains("after"))
    assert_eq(visited.contains("independent"), keep_going)
  }
}

///|
async test "make parser expands variables and merges rule dependencies" {
  let database : Database = {
    cwd: ".",
    variables: Map([]),
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    "NAME = output\n$(NAME): first\n$(NAME): second\n\tprintf $@:$<:$^\n", database,
    ".", 0,
  )
  debug_inspect(database.default_target, content="Some(\"output\")")
  guard database.rules.get("output") is Some(rule) else {
    fail("missing parsed rule")
  }
  debug_inspect(rule.dependencies, content="[\"first\", \"second\"]")
  debug_inspect(rule.recipes, content="[\"printf $@:$<:$^\"]")
}

///|
async test "make parser marks phony targets declared before their rule" {
  let database : Database = {
    cwd: ".",
    variables: Map([]),
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(".PHONY: clean\nclean:\n\techo clean\n", database, ".", 0)
  guard database.rules.get("clean") is Some(rule) else {
    fail("missing phony rule")
  }
  assert_true(rule.phony)
  debug_inspect(rule.recipes, content="[\"echo clean\"]")
}

///|
async test "make conditionals select one rule and pattern dependencies use stems" {
  let database : Database = {
    cwd: ".",
    variables: Map([]),
    command_line_variables: Map([]),
    exported: Set([]),
    rules: Map([]),
    default_target: None,
  }
  parse_makefile(
    "MODE = yes\nifeq ($(MODE),yes)\nall: ready\n\techo yes\nelse\nall:\n\techo no\nendif\n%.o: %.c\n\techo $* $<\nfoo.o: %.o: %.c\n\techo $*\n",
    database, ".", 0,
  )
  guard database.rules.get("all") is Some(all) else {
    fail("missing conditional rule")
  }
  assert_eq(all.dependencies, ["ready"])
  guard database.rules.get("%.o") is Some(pattern) else {
    fail("missing pattern rule")
  }
  assert_eq(pattern.dependencies, ["%.c"])
  guard database.rules.get("foo.o") is Some(static_pattern) else {
    fail("missing static pattern rule")
  }
  assert_eq(static_pattern.dependencies, ["foo.c"])
  assert_eq(static_pattern.stem, Some("foo"))
  assert_true(positive_job_count("2"))
  assert_false(positive_job_count("0"))
  assert_false(positive_job_count("all"))
}
