///|
priv suberror ExpansionFailure {
  ExpansionFailure(String)
}

///|
priv struct PreparedRecipe {
  command : String
  silent : Bool
  ignore_error : Bool
  recursive : Bool
}

///|
priv struct PreparedRecipes {
  commands : Array[PreparedRecipe]
  automatic : Map[String, String]
  mut environment : Map[String, String]?
}

///|
async fn prepare_recipes(
  rule : Rule,
  database : Database,
  settings : Settings,
  newer_dependencies : Array[String],
) -> PreparedRecipes {
  settings.expansion_lock.acquire()
  defer settings.expansion_lock.release()
  let automatic = automatic_variables(
    rule.target,
    rule.stem,
    rule.dependencies,
    newer_dependencies~,
  )
  let commands : Array[PreparedRecipe] = []
  for recipe in rule.recipes {
    let mut command = expand(
      recipe,
      database.variables,
      automatic,
      0,
      cwd=settings.cwd,
      exported=database.exported,
      state=database.expansion(),
    ) catch {
      MakeError(message) => raise ExpansionFailure(message)
      error => raise error
    }
    let mut silent = settings.silent
    let mut ignore_error = false
    let mut recursive = recipe.contains("$(MAKE)") || recipe.contains("${MAKE}")
    let mut scanning = true
    while scanning && command != "" {
      match command[0] {
        '@' => {
          silent = true
          command = command[1:].to_owned()
        }
        '-' => {
          ignore_error = true
          command = command[1:].to_owned()
        }
        '+' => {
          recursive = true
          command = command[1:].to_owned()
        }
        ' ' | '\t' => command = command[1:].to_owned()
        _ => scanning = false
      }
    }
    commands.push({ command, silent, ignore_error, recursive, })
  }
  { commands, automatic, environment: None, }
}

///|
async fn run_recipe(
  recipe : PreparedRecipe,
  prepared : PreparedRecipes,
  database : Database,
  settings : Settings,
) -> Int32 {
  settings.expansion_lock.acquire()
  let mut expanding = true
  defer (if expanding { settings.expansion_lock.release() })
  if recipe.command.trim().is_empty() {
    return 0
  }
  if !recipe.silent || settings.dry_run {
    @stdio.stdout.write(recipe.command + "\n")
  }
  // GNU avoids constructing a target environment for a pure colon no-op,
  // empty recipes, and dry-run lines that do not actually execute.
  if recipe.command == ":" || (settings.dry_run && !recipe.recursive) {
    return 0
  }
  let environment = match prepared.environment {
    Some(environment) => environment
    None => {
      let environment = command_environment(
        database,
        automatic=prepared.automatic,
      ) catch {
        MakeError(message) => raise ExpansionFailure(message)
        error => raise error
      }
      prepared.environment = Some(environment)
      environment
    }
  }
  expanding = false
  settings.expansion_lock.release()
  let status = execute_shell(
    @shell.Session::new(name="make", env=environment, cwd=settings.cwd),
    recipe.command,
  )
  if status != 0 && !recipe.ignore_error {
    status
  } else {
    0
  }
}
