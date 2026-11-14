///|
priv suberror ModuleError {
  ModuleError(String)
}

///|
priv suberror ModuleReadError {
  ModuleReadError(String)
}

///|
fn module_home(windows : Bool, environment : (String) -> String?) -> String? {
  if environment("HOME") is Some(home) {
    return Some(home)
  }
  if windows {
    if environment("USERPROFILE") is Some(home) {
      return Some(home)
    }
    if environment("HOMEPATH") is Some(path) {
      return Some(environment("HOMEDRIVE").unwrap_or("") + path)
    }
  }
  None
}

///|
priv struct Linked {
  scope : @ast.Env
  exports : Array[(String, Int32)]
  body : @ast.Expr
}

///|
priv struct Modules {
  paths : Array[String]
  home : String?
  origin : String
  globals : @ast.Env
  loading : Set[String]
  loaded : Map[String, Linked]
  sources : Map[String, String]
}

///|
fn Modules::new(options : CliOptions) -> Modules raise {
  let home = module_home(@platform.is_windows(), @env.get_env_var)
  let origin = @path.Path(@env.args().get(0).unwrap_or("."))
    .resolve()
    .dirname()
    .to_string()
  let paths = if options.library_paths.is_empty() {
    ["~/.jq", "$ORIGIN/../lib/jq", "$ORIGIN/../lib"]
  } else {
    options.library_paths.map(path => @path.Path(path).resolve().to_string())
  }
  let mut globals = @ast.Env::new()
  for name, value in options.arguments {
    globals = globals.set(name, @json.parse(value))
  }
  {
    paths,
    home,
    origin,
    globals,
    loading: Set([]),
    loaded: Map([]),
    sources: Map([]),
  }
}

///|
fn module_path_valid(name : String) -> Unit raise ModuleError {
  if name.contains("\u{0}") {
    raise ModuleError("Module path contains a NUL byte")
  }
  if name.contains("\\") {
    raise ModuleError(
      "Modules must be named by relative paths using '/', not '\\' (\{name})",
    )
  }
  let components = name.split("/").map(part => part.to_owned()).collect()
  let mut previous = ""
  for component in components {
    if component == ".." {
      raise ModuleError(
        "Relative paths to modules may not traverse to parent directories (\{name})",
      )
    }
    if component != "" && component == previous {
      raise ModuleError(
        "module names must not have equal consecutive components: \{name}",
      )
    }
    previous = component
  }
}

///|
fn Modules::search(
  self : Modules,
  metadata : Json,
  directory : String?,
) -> Array[String] {
  let search = match metadata {
    Object(fields) => fields.get("search")
    _ => None
  }
  let entries : Array[Json] = match search {
    None => [Json::string("."), ..self.paths.map(Json::string)]
    Some(Array(values)) => values
    Some(value) => [value]
  }
  let result : Array[String] = []
  for entry in entries {
    guard entry is String(path) && path != "" else { continue }
    let expanded = if path == "~" || path.has_prefix("~/") {
      match self.home {
        Some(home) => home + path[1:].to_owned()
        None => continue
      }
    } else if path.has_prefix("$ORIGIN/") {
      self.origin + path[7:].to_owned()
    } else if path != "." &&
      !@path.Path(path).is_absolute() &&
      directory is Some(directory) {
      @path.Path(directory).join(@path.Path(path)).to_string()
    } else {
      path
    }
    result.push(expanded)
  }
  result
}

///|
async fn Modules::find(
  self : Modules,
  name : String,
  data : Bool,
  metadata : Json,
  directory : String?,
) -> String {
  module_path_valid(name)
  let suffix = if data { ".json" } else { ".jq" }
  for directory in self.search(metadata, directory) {
    let base = directory + "/" + name
    for
      candidate in [
        base + suffix,
        base + "/jq/main" + suffix,
        base + "/" + @path.Path(name).basename().to_owned() + suffix,
      ] {
      if @fs.exists(candidate) {
        return @fs.realpath(candidate)
      }
    }
  }
  raise ModuleError("module not found: \{name}")
}

///|
async fn Modules::load(self : Modules, path : String) -> Linked {
  if self.loading.contains(path) {
    raise ModuleError("circular import of \{path}")
  }
  if self.loaded.get(path) is Some(value) {
    return value
  }
  self.loading.add(path)
  defer self.loading.remove(path)
  let source = @fs.read_file(path).text() catch {
    error => raise ModuleReadError(error.to_string())
  }
  self.sources[path] = source
  let program = @parser.parse_program(source, library=true)
  let linked = self.link(
    program,
    Some(@path.Path(path).dirname().to_string()),
    self.globals.with_source(path),
  )
  self.loaded[path] = linked
  linked
}

///|
async fn Modules::link(
  self : Modules,
  program : @parser.Program,
  directory : String?,
  initial : @ast.Env,
) -> Linked {
  let mut scope = initial
  for dependency in program.dependencies {
    let optional = dependency.metadata is { "optional": True, .. }
    let path = self.find(
      dependency.path,
      dependency.data,
      dependency.metadata,
      directory,
    ) catch {
      ModuleError(_) as error => if optional { continue } else { raise error }
      error => raise error
    }
    if dependency.data {
      let value = try {
        let file = @fs.open(path, mode=ReadOnly)
        defer file.close()
        if dependency.metadata is { "raw": True, .. } {
          Json::string(@utf8.decode_lossy(file.read_all().binary()))
        } else {
          let parser = StreamInput::new(file)
          let values : Array[Json] = []
          while parser.next_json() is Some(value) {
            values.push(value)
          }
          Json::array(values)
        }
      } catch {
        StreamError(message, line, column) =>
          if optional {
            continue
          } else {
            raise ModuleError(
              "error loading data file \{path}: \{message} at line \{line}, column \{column}",
            )
          }
        error => if optional { continue } else { raise error }
      }
      let name = dependency.binding.unwrap()
      scope = scope.set(name, value).set(name + "::" + name, value)
    } else {
      let imported = self.load(path) catch {
        ModuleReadError(_) as error =>
          if optional {
            continue
          } else {
            raise error
          }
        error => raise error
      }
      scope = scope.import_functions(
        imported.scope,
        imported.exports,
        dependency.binding,
      )
    }
  }
  let exports : Array[(String, Int32)] = []
  for body = program.body {
    match body {
      Pipe(FunctionDef(name, parameters, filter), rest) => {
        scope = scope.set_function(name, lower(filter), parameters)
        exports.push((name, parameters.length()))
        continue rest
      }
      _ => break { scope, exports, body: lower(body), }
    }
  }
}

///|
async fn Modules::main_scope(self : Modules) -> @ast.Env {
  if self.home is Some(home) {
    let prelude = home + "/.jq"
    let regular = (@fs.kind(prelude, follow_symlink=true) == Regular) catch {
      _ => false
    }
    if regular {
      let imported = self.load(@fs.realpath(prelude))
      return self.globals.import_functions(
        imported.scope,
        imported.exports,
        None,
      )
    }
  }
  self.globals
}

///|
async fn Modules::metadata(
  self : Modules,
  name : String,
  report : async (String) -> Unit,
) -> Json {
  let path = self.find(
    name,
    false,
    { "search": Json::array(self.paths.map(Json::string)) },
    None,
  )
  let source = @fs.read_file(path).text()
  let program = @parser.parse_program(source, library=true) catch {
    error => {
      report("moonjq: \{error}\n")
      return null
    }
  }
  let fields = match program.metadata {
    Object(fields) => fields.copy()
    _ => Map([])
  }
  fields["deps"] = Json::array(
    program.dependencies.map(dependency => {
      let data = match dependency.metadata {
        Object(fields) => fields.copy()
        _ => Map([])
      }
      if dependency.binding is Some(name) {
        data["as"] = Json::string(name)
      }
      data["is_data"] = Json::boolean(dependency.data)
      data["relpath"] = Json::string(dependency.path)
      Json::object(data)
    }),
  )
  let definitions : Array[Json] = []
  for body = program.body {
    match body {
      Pipe(FunctionDef(name, parameters, _), rest) => {
        definitions.push(Json::string("\{name}/\{parameters.length()}"))
        continue rest
      }
      _ => break
    }
  }
  fields["defs"] = Json::array(definitions)
  Json::object(fields)
}
