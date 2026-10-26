///|
pub fn option_child_path() -> String {
  option_child_executable(@env.args()[0])
}

///|
fn option_child_executable(program : String) -> String {
  @path.Path(
    // Path.resolve uses the released win32 resolver on Windows, including
    // drive-relative argv[0], before a child receives a different fixture cwd.
    program,
  )
  .resolve()
  .to_string()
  .replace_all(old="\\", new="/")
}

///|
pub fn option_child_required(fixture : Case) -> Bool {
  fixture.id.has_prefix("tee-output-errors") ||
  fixture.args.any(arg => {
    arg.contains("${PRINTF_CHILD}") ||
    arg.contains("${PRINTENV_CHILD}") ||
    arg.contains("${RG_PREPROCESSOR}")
  })
}

///|
fn option_child_words(kind : String) -> Array[String] {
  [option_child_path(), "--option-test-helper", kind]
}

///|
fn option_child_source(kind : String) -> String {
  "'" +
  option_child_path().replace_all(old="'", new="'\\''") +
  "' --option-test-helper " +
  kind
}

///|
pub async fn run_option_child(args : ArrayView[String]) -> Int32 {
  match args {
    ["tee-modes", program, work] => {
      check_tee_modes(program, [], work)
      0
    }
    ["printenv", .. names] => {
      let mut status = 0
      for name in names {
        match @env.get_env_var(name) {
          Some(value) => @stdio.stdout.write(value + "\n")
          None => status = 1
        }
      }
      status
    }
    ["printf", format, .. values] => {
      let chars = format.iter().collect()
      let mut argument = 0
      let mut first = true
      while first || argument < values.length() {
        first = false
        let before = argument
        let output = StringBuilder()
        for index = 0; index < chars.length(); {
          if chars[index] == '%' && index + 1 < chars.length() {
            guard chars[index + 1] is ('s' | '%') else {
              fail("fixture supports only %s and %%")
            }
            if chars[index + 1] == '%' {
              output.write_char('%')
            } else {
              output.write_string(values.get(argument).unwrap_or(""))
              argument += 1
            }
            continue index + 2
          }
          if chars[index] == '\\' &&
            index + 1 < chars.length() &&
            chars[index + 1] == 'n' {
            output.write_char('\n')
            continue index + 2
          }
          output.write_char(chars[index])
          continue index + 1
        }
        @stdio.stdout.write(output.to_string())
        if argument == before {
          break
        }
      }
      0
    }
    _ => fail("unknown controlled option child")
  }
}
