// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `info` command (upstream `typst-cli/src/info.rs`).

///|
/// The environment variables that are of interest to Typst.
fn env_var_names() -> Array[String] {
  let names = [
    "TYPST_CERT", "TYPST_FEATURES", "TYPST_FONT_PATHS", "TYPST_IGNORE_SYSTEM_FONTS",
    "TYPST_IGNORE_EMBEDDED_FONTS", "TYPST_PACKAGE_CACHE_PATH", "TYPST_PACKAGE_PATH",
    "TYPST_ROOT", "TYPST_UPDATE_BACKUP_PATH", "SOURCE_DATE_EPOCH",
  ]
  if @platform.os() == Linux {
    names.append([
      "XDG_CACHE_HOME", "XDG_DATA_HOME", "FONTCONFIG_FILE", "OPENSSL_CONF",
    ])
  }
  names.append([
    "NO_COLOR", "NO_PROXY", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY",
  ])
  names
}

///|
/// The operating system name (`std::env::consts::OS`).
fn os_name() -> String {
  match @platform.os() {
    Linux => "linux"
    MacOs => "macos"
    Windows => "windows"
  }
}

///|
/// Execute an info command.
async fn info(command : InfoCommand) -> Unit {
  let env = env_var_names().map(key => (key, @platform.env_var(key)))
  let get = (key : String) => {
    match env.iter().find_first(e => e.0 == key) {
      Some((_, value)) => value
      None => None
    }
  }

  // Turns a comma separated list of feature names into feature flags.
  let mut html = false
  let mut bundle = false
  let mut a11y_extras = false
  for feature in get("TYPST_FEATURES").unwrap_or("").split(",") {
    match feature.to_owned() {
      "" => ()
      "html" => html = true
      "bundle" => bundle = true
      "a11y-extras" => a11y_extras = true
      other => print_error("unknown runtime feature: `\{other}`")
    }
  }
  let font_paths = get("TYPST_FONT_PATHS")
    .unwrap_or("")
    .split(":")
    .filter(s => s != "")
    .map(s => s.to_owned())
    .to_array()
  let parse_env_bool : async (String) -> Bool = key => {
    match get(key) {
      None => false
      Some("true") => true
      Some("false") => false
      Some(val) => {
        print_error(
          "invalid value `\{val}` for `\{key}`, expected `true` or `false`.",
        )
        false
      }
    }
  }
  let system = !parse_env_bool("TYPST_IGNORE_SYSTEM_FONTS")
  let embedded = !parse_env_bool("TYPST_IGNORE_EMBEDDED_FONTS")
  let package_path = match get("TYPST_PACKAGE_PATH") {
    Some(path) => Some(path)
    None => @kit.FsPackages::system_data().map(fs => fs.path())
  }
  let package_cache_path = match get("TYPST_PACKAGE_CACHE_PATH") {
    Some(path) => Some(path)
    None => @kit.FsPackages::system_cache().map(fs => fs.path())
  }
  let arch = if @platform.supports_binary_stdout() {
    @platform.arch()
  } else {
    "wasm32"
  }
  match command.format {
    Some(format) => {
      let opt = (v : String?) => {
        match v {
          Some(s) => @serde.Data::Str(s)
          None => @serde.Data::None
        }
      }
      let value : @serde.Data = Map([
        ("version", Str(typst_version)),
        (
          "build",
          Map([
            ("commit", Str(upstream_commit)),
            ("platform", Map([("os", Str(os_name())), ("arch", Str(arch))])),
            (
              "settings",
              Map([("self-update", Bool(false)), ("http-server", Bool(false))]),
            ),
          ]),
        ),
        (
          "features",
          Map([
            ("html", Bool(html)),
            ("bundle", Bool(bundle)),
            ("a11y-extras", Bool(a11y_extras)),
          ]),
        ),
        (
          "fonts",
          Map([
            ("paths", Seq(font_paths.map(p => @serde.Data::Str(p)))),
            ("system", Bool(system)),
            ("embedded", Bool(embedded)),
          ]),
        ),
        (
          "packages",
          Map([
            ("package-path", opt(package_path)),
            ("package-cache-path", opt(package_cache_path)),
          ]),
        ),
        ("env", Map(env.map(e => (e.0, opt(e.1))))),
      ])
      let serialized = match format {
        Json => @tjson.to_string(value, pretty=command.pretty)
        Yaml =>
          @yaml.to_string(value) catch {
            @yaml.YamlError(message~, ..) => raise bail(message)
          }
      }
      print_out(serialized + "\n")
    }
    None => {
      let out = terminal_out()
      let key = (k : String, pad : Int32?) => {
        out.set_color(@kit.ColorSpec::new().with_fg(Cyan))
        out.write(pad_right(k, pad))
        out.reset()
      }
      let simple = (v : String, pad : Int32?) => {
        out.set_color(@kit.ColorSpec::new().with_fg(Green))
        out.write(pad_right(v, pad))
        out.reset()
      }
      let special = (v : String, pad : Int32?) => {
        out.set_color(@kit.ColorSpec::new().with_fg(Blue))
        out.write(pad_right(v, pad))
        out.reset()
      }
      let bool_value = (b : Bool, pad : Int32?) => {
        special(if b { "on" } else { "off" }, pad)
      }
      let opt_value = (v : String?) => {
        match v {
          Some(v) => simple(v, None)
          None => special("<unset>", None)
        }
      }
      key("Version", None)
      out.write(" ")
      simple(typst_version, None)
      out.write(" (")
      simple(upstream_commit[:8].to_owned(), None)
      out.write(", ")
      simple(os_name(), None)
      out.write(" on ")
      simple(arch, None)
      out.writeln(")\n")
      out.writeln("Build settings")
      for
        entry in [
          ("self-update", false, "Update Typst via `typst update`"),
          ("http-server", false, "Serve HTML via `typst watch`"),
        ] {
        out.write("  ")
        key(entry.0, Some(11))
        out.write(" ")
        bool_value(entry.1, Some(3))
        out.writeln(" (\{entry.2})")
      }
      out.writeln("")
      out.writeln("Features")
      for
        entry in [
          ("html", html, "Experimental HTML export"),
          ("bundle", bundle, "Experimental bundle export"),
          ("a11y-extras", a11y_extras, "Experimental accessibility additions"),
        ] {
        out.write("  ")
        key(entry.0, Some(11))
        out.write(" ")
        bool_value(entry.1, Some(3))
        out.writeln(" (\{entry.2})")
      }
      out.writeln("")
      out.writeln("Fonts")
      out.write("  ")
      key("Custom font paths", None)
      if font_paths.is_empty() {
        out.write(" ")
        special("<none>", None)
        out.writeln("")
      } else {
        out.writeln("")
        for path in font_paths {
          out.write("    - ")
          simple(path, None)
          out.writeln("")
        }
      }
      for entry in [("System fonts", system), ("Embedded fonts", embedded)] {
        out.write("  ")
        key(entry.0, Some(14))
        out.write(" ")
        bool_value(entry.1, None)
        out.writeln("")
      }
      out.writeln("")
      out.writeln("Packages")
      for
        entry in [
          ("Package path", package_path),
          ("Package cache path", package_cache_path),
        ] {
        out.write("  ")
        key(entry.0, Some(18))
        out.write(" ")
        opt_value(entry.1)
        out.writeln("")
      }
      out.writeln("")
      out.writeln("Environment variables")
      let mut key_pad = 0
      for e in env {
        if e.0.length() > key_pad {
          key_pad = e.0.length()
        }
      }
      for e in env {
        out.write("  ")
        key(e.0, Some(key_pad))
        out.write(" ")
        opt_value(e.1)
        out.writeln("")
      }
      flush_terminal(out)
    }
  }
}

///|
/// Pads a string with spaces to the right (`{: <pad$}`).
fn pad_right(s : String, pad : Int32?) -> String {
  match pad {
    Some(pad) => {
      let len = s.iter().count()
      if len < pad {
        s + " ".repeat(pad - len)
      } else {
        s
      }
    }
    None => s
  }
}
