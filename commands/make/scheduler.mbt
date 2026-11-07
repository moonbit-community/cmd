///|
priv struct BuildNode {
  target : String
  rule : Rule?
  dependencies : Array[String]
}

///|
async fn plan_target(
  target : String,
  database : Database,
  visiting : Set[String],
  planned : Set[String],
  order : Array[BuildNode],
) -> Unit {
  if planned.contains(target) {
    return
  }
  if visiting.contains(target) {
    raise MakeError("dependency cycle detected at '\{target}'")
  }
  visiting.add(target)
  let rule = match database.rules.get(target) {
    Some(rule) => Some(rule)
    None => {
      let mut matched = None
      for candidate in database.rules.values() {
        if instantiate_pattern(candidate, target) is Some(rule) {
          matched = Some(rule)
          break
        }
      }
      matched
    }
  }
  let dependencies = match rule {
    Some(rule) => resolve_prerequisites(rule, database)
    None => []
  }
  let rule = rule.map(rule => { ..rule, dependencies, })
  for dependency in dependencies {
    plan_target(dependency, database, visiting, planned, order)
  }
  visiting.remove(target)
  planned.add(target)
  order.push({ target, rule, dependencies, })
}

///|
async fn execute_target(
  node : BuildNode,
  database : Database,
  settings : Settings,
) -> Unit {
  let target_path = path_in(settings.cwd, node.target)
  let target_virtual = settings.what_if.contains(node.target)
  guard node.rule is Some(rule) else {
    if !target_virtual && !@fs.exists(target_path) {
      raise MakeError("no rule to make target '\{node.target}'")
    }
    return
  }
  let target_exists = target_virtual || (!rule.phony && @fs.exists(target_path))
  let newer_dependencies : Array[String] = []
  for dependency in rule.dependencies {
    let dependency_path = path_in(settings.cwd, dependency)
    let dependency_virtual = settings.what_if.contains(dependency)
    if !target_exists ||
      settings.always_make ||
      (dependency_virtual && !target_virtual) ||
      (
        !dependency_virtual &&
        (
          database.rules.get(dependency) is Some({ phony: true, .. }) ||
          !@fs.exists(dependency_path) ||
          (!target_virtual && newer(dependency_path, target_path))
        )
      ) {
      newer_dependencies.push(dependency)
    }
  }
  let rebuild = settings.always_make ||
    !target_exists ||
    !newer_dependencies.is_empty()
  if rebuild {
    for recipe in rule.recipes {
      let status = run_recipe(
        recipe,
        rule,
        database,
        settings,
        newer_dependencies~,
      )
      if status != 0 {
        raise MakeError(
          "recipe for '\{node.target}' failed with status \{status}",
        )
      }
    }
  }
}

///|
async fn build_targets(
  targets : Array[String],
  database : Database,
  settings : Settings,
  execute~ : async (BuildNode, Database, Settings) -> Unit = execute_target,
) -> Unit {
  let order : Array[BuildNode] = []
  let planned : Set[String] = Set([])
  for target in targets {
    plan_target(target, database, Set([]), planned, order)
  }
  let slots = @semaphore.Semaphore(
    if settings.jobs == 0 {
      order.length().max(1)
    } else {
      settings.jobs
    },
  )
  let failures = Ref(0)
  @async.with_task_group() <| group => {
    let tasks : Map[String, @async.Task[Bool]] = Map([])
    for node in order {
      // Dependencies precede their users in order, and each target is spawned
      // once even when several recipes share it.
      let dependencies = node.dependencies.map(name => tasks[name])
      tasks[node.target] = group.spawn(() => {
        for dependency in dependencies {
          if !dependency.wait() {
            return false
          }
        }
        let action : async () -> Bool = () => {
          if failures.val > 0 && !settings.keep_going {
            return false
          }
          execute(node, database, settings) catch {
            err => {
              failures.val += 1
              let message = match err {
                MakeError(message) => message
                _ => err.to_string()
              }
              @stdio.stderr.write("make: \{message}\n")
              return false
            }
          }
          true
        }
        match settings.jobserver {
          Some(server) => server.with_slot(action)
          None => {
            slots.acquire()
            defer slots.release()
            action()
          }
        }
      })
    }
    for task in tasks.values() {
      ignore(task.wait())
    }
  }
  if failures.val > 0 {
    raise MakeError("\{failures.val} target(s) failed")
  }
}
