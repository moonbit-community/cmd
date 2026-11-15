///|
pub(all) struct Result {
  out : Bytes
  messages : Array[String]
  fatal : String?
  exit_error : Bool
}

///|
pub fn render(format : String, args : Array[String]) -> Result {
  let ctx : Context = {
    out: [],
    args,
    arg_index: 0,
    messages: [],
    exit_error: false,
    stop: false,
    fatal: None,
  }
  let fmt_chars : Array[Char] = format.iter().collect()
  for ;; {
    let before = ctx.arg_index
    scan_format(ctx, fmt_chars)
    if ctx.stop || !(ctx.fatal is None) {
      break
    }
    if ctx.arg_index >= ctx.args.length() {
      break
    }
    if ctx.arg_index == before {
      ctx.notice(
        "printf: warning: ignoring excess arguments, starting with '\{ctx.args[ctx.arg_index]}'",
      )
      break
    }
  }
  {
    out: Bytes::from_array(ctx.out),
    messages: ctx.messages,
    fatal: ctx.fatal,
    exit_error: ctx.exit_error,
  }
}
