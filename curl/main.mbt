///|
async fn main {
  let args = @env.args()[1:]
  let mut output_path : String? = None
  let mut fail_on_http_error = false
  let mut silent = false
  let mut url : String? = None
  let mut options = true
  let mut failed = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-s" || arg == "--silent") {
      silent = true
    } else if options && (arg == "-S" || arg == "--show-error") {
      silent = false
    } else if options && (arg == "-f" || arg == "--fail") {
      fail_on_http_error = true
    } else if options && (arg == "-o" || arg == "--output") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("curl: option requires an argument: \{arg}\n")
        @sys.exit(2)
        return
      }
      i += 1
      output_path = Some(args[i])
    } else if options && arg.has_prefix("-o") && arg.length() > 2 {
      output_path = Some(arg[2:].to_owned())
    } else if options &&
      arg.has_prefix("-") &&
      !arg.has_prefix("--") &&
      arg != "-" {
      let mut valid = true
      for flag in arg[1:] {
        match flag {
          's' => silent = true
          'S' => silent = false
          'f' => fail_on_http_error = true
          _ => valid = false
        }
      }
      if !valid {
        @stdio.stderr.write("curl: unsupported option: \{arg}\n")
        @sys.exit(2)
        return
      }
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: curl [-sSf] [-o FILE] URL\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("curl: unsupported option: \{arg}\n")
      @sys.exit(2)
      return
    } else if url is None {
      url = Some(arg)
    } else {
      @stdio.stderr.write("curl: only one URL is supported\n")
      @sys.exit(2)
      return
    }
    i += 1
  }
  let target = match url {
    Some(value) => value
    None => {
      @stdio.stderr.write("curl: missing URL\n")
      @sys.exit(2)
      return
    }
  }
  let destination = match output_path {
    Some("-") => None
    other => other
  }
  @netops.fetch(target, destination, fail_on_http_error) catch {
    err => {
      if !silent {
        @stdio.stderr.write("curl: \{err}\n")
      }
      failed = true
    }
  }
  if failed {
    @sys.exit(1)
  }
}
