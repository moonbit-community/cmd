///|
async fn main {
  let args = @env.args()[1:]
  let mut output_path : String? = None
  let mut error_path : String? = None
  let mut quiet = false
  let urls : Array[String] = []
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-q" || arg == "--quiet") {
      quiet = true
    } else if options && (arg == "-O" || arg == "--output-document") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("wget: option requires an argument: \{arg}\n")
        @sys.exit(2)
        return
      }
      i += 1
      output_path = Some(args[i])
    } else if options && arg.has_prefix("-O") && arg.length() > 2 {
      output_path = Some(arg[2:].to_owned())
    } else if options && (arg == "-o" || arg == "--output-file") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("wget: option requires an argument: \{arg}\n")
        @sys.exit(2)
        return
      }
      i += 1
      error_path = Some(args[i])
    } else if options && arg == "--help" {
      @stdio.stdout.write("Usage: wget [-q] [-O FILE] URL\n")
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("wget: unsupported option: \{arg}\n")
      @sys.exit(2)
      return
    } else {
      urls.push(arg)
    }
    i += 1
  }
  if urls.length() != 1 {
    @stdio.stderr.write("wget: exactly one URL is required\n")
    @sys.exit(2)
    return
  }
  let destination = match output_path {
    Some("-") => None
    Some(path) => Some(path)
    None => Some(@path.Path(urls[0]).basename().to_owned())
  }
  @netops.fetch(urls[0], destination, false) catch {
    err => {
      if !quiet {
        match error_path {
          None => @stdio.stderr.write("wget: \{err}\n")
          Some(path) => {
            let output = @fs.open(
              path,
              mode=WriteOnly,
              create_mode=CreateOrTruncate,
            )
            output.write("wget: \{err}\n")
            output.close()
          }
        }
      }
      @sys.exit(1)
      return
    }
  }
}
