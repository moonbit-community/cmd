///|
priv struct Ctx {
  out : Array[Byte]
  args : Array[String]
  mut arg_index : Int32
  messages : Array[String]
  mut exit_error : Bool
  mut stop : Bool
  mut fatal : String?
}

///|
fn help_message() -> String {
  let message =
    #|Usage: printf FORMAT [ARGUMENT...]
    #|      --help      display this help and exit
    #|      --version   display version and exit
    #|
    #|Format and print ARGUMENTs under control of FORMAT, like printf(1).
    #|The FORMAT is reused as necessary to consume all arguments.
    #|
    #|Escapes: \a \b \e \f \n \r \t \v \\ \" \' \NNN \0NNN \xHH \uHHHH
    #|\UHHHHHHHH, and \c (stop all output).
    #|
    #|Conversions: %s %c %b %d %i %u %o %x %X %f %F %e %E %g %G %a %A %%, with the
    #|flags -+ 0#, field width, and precision (both accept *).
    #|%b interprets escapes in its argument.
    #|Bare %q quotes an argument for a shell under the C-byte profile.
    #|
    #|Use -- before a FORMAT that starts with '-'.
  message
}

///|
fn Ctx::next_arg(self : Ctx) -> String? {
  if self.arg_index < self.args.length() {
    let value = self.args[self.arg_index]
    self.arg_index += 1
    Some(value)
  } else {
    None
  }
}

///|
/// Record a diagnostic that also makes the final exit status 1.
fn Ctx::warn(self : Ctx, msg : String) -> Unit {
  self.messages.push(msg)
  self.exit_error = true
}

///|
/// Record a diagnostic that leaves the exit status unchanged.
fn Ctx::notice(self : Ctx, msg : String) -> Unit {
  self.messages.push(msg)
}

///|
fn is_blank(c : Char) -> Bool {
  c.to_int() is (0x20 | 0x09 | 0x0A | 0x0D | 0x0B | 0x0C)
}

///|
let uint64_max : UInt64 = 0xFFFF_FFFF_FFFF_FFFF

///|
let int64_max_mag : UInt64 = 0x7FFF_FFFF_FFFF_FFFF

///|
let int64_min_mag : UInt64 = 0x8000_0000_0000_0000

///|
let float_profile : @numfmt.Profile = @numfmt.Extended80

///|
/// Parse a printf integer argument like strtoimax/strtoumax: leading blanks,
/// 'C or "C for a character code, then the longest valid decimal, 0x hex, or
/// leading-0 octal prefix. Trailing text warns; overflow clamps and warns.
/// Returns the value's 64-bit pattern.
fn parse_integer(ctx : Ctx, text : String, unsigned~ : Bool) -> Int64 {
  let chars : Array[Char] = text.iter().collect()
  let mut i = 0
  while i < chars.length() && is_blank(chars[i]) {
    i += 1
  }
  if i >= chars.length() {
    ctx.warn("printf: '\{text}': expected a numeric value")
    return 0
  }
  if chars[i] == '\'' || chars[i] == '"' {
    if i + 1 >= chars.length() {
      ctx.warn("printf: '\{text}': expected a numeric value")
      return 0
    }
    if i + 2 < chars.length() {
      let sb = StringBuilder()
      for k in (i + 2)..<chars.length() {
        sb.write_char(chars[k])
      }
      ctx.notice(
        "printf: warning: \{sb}: character(s) following character constant have been ignored",
      )
    }
    return chars[i + 1].to_int().to_int64()
  }
  let mut neg = false
  if chars[i] == '+' || chars[i] == '-' {
    neg = chars[i] == '-'
    i += 1
  }
  let mut base = 10
  let mut digits_start = i
  if i < chars.length() &&
    chars[i] == '0' &&
    i + 1 < chars.length() &&
    (chars[i + 1] == 'x' || chars[i + 1] == 'X') &&
    i + 2 < chars.length() &&
    hex_val(chars[i + 2]) >= 0 {
    base = 16
    digits_start = i + 2
  } else if i < chars.length() && chars[i] == '0' {
    base = 8
  }
  let mut j = digits_start
  let mut any = false
  let mut mag : UInt64 = 0
  let mut overflow = false
  while j < chars.length() {
    let d = match base {
      16 => hex_val(chars[j])
      8 => if chars[j] is ('0'..<='7') { chars[j].to_int() - 0x30 } else { -1 }
      _ => if chars[j] is ('0'..<='9') { chars[j].to_int() - 0x30 } else { -1 }
    }
    if d < 0 {
      break
    }
    any = true
    let big_base = base.to_int64().reinterpret_as_uint64()
    let big_d = d.to_int64().reinterpret_as_uint64()
    if mag > (uint64_max - big_d) / big_base {
      overflow = true
    } else {
      mag = mag * big_base + big_d
    }
    j += 1
  }
  if !any {
    ctx.warn("printf: '\{text}': expected a numeric value")
    return 0
  }
  // A range error supersedes the partial-conversion warning, like GNU.
  let range_error = if unsigned {
    overflow
  } else if neg {
    overflow || mag > int64_min_mag
  } else {
    overflow || mag > int64_max_mag
  }
  if range_error {
    ctx.warn("printf: '\{text}': Numerical result out of range")
    return if unsigned {
      uint64_max.reinterpret_as_int64()
    } else if neg {
      int64_min_mag.reinterpret_as_int64()
    } else {
      int64_max_mag.reinterpret_as_int64()
    }
  }
  if j < chars.length() {
    ctx.warn("printf: '\{text}': value not completely converted")
  }
  let bits = mag.reinterpret_as_int64()
  if neg {
    -bits
  } else {
    bits
  }
}

///|
fn parse_float_arg(ctx : Ctx, text : String) -> @numfmt.Value {
  let chars : Array[Char] = text.iter().collect()
  let mut index = 0
  while index < chars.length() && is_blank(chars[index]) {
    index += 1
  }
  if index < chars.length() && chars[index] is ('\'' | '"') {
    if index + 1 >= chars.length() {
      ctx.warn("printf: '\{text}': expected a numeric value")
      return @numfmt.zero()
    }
    if index + 2 < chars.length() {
      let suffix = StringBuilder()
      for next in (index + 2)..<chars.length() {
        suffix.write_char(chars[next])
      }
      ctx.notice(
        "printf: warning: \{suffix}: character(s) following character constant have been ignored",
      )
    }
    return @numfmt.parse_prefix(
        chars[index + 1].to_int().to_string(),
        float_profile,
      ).0
  }
  let (number, consumed, range_error) = @numfmt.parse_prefix(
    text, float_profile,
  )
  if consumed == 0 {
    ctx.warn("printf: '\{text}': expected a numeric value")
  } else if range_error {
    ctx.warn("printf: '\{text}': Numerical result out of range")
  } else if consumed < chars.length() {
    ctx.warn("printf: '\{text}': value not completely converted")
  }
  number
}

///|
fn emit_signed(
  ctx : Ctx,
  n : Int64,
  width : Int32?,
  prec : Int32?,
  minus : Bool,
  plus : Bool,
  space : Bool,
  zero : Bool,
) -> Unit {
  let negf = n < 0
  let mag = if negf {
    (-n).reinterpret_as_uint64()
  } else {
    n.reinterpret_as_uint64()
  }
  let body = apply_precision(mag.to_string(), prec)
  let sign = if negf {
    "-"
  } else if plus {
    "+"
  } else if space {
    " "
  } else {
    ""
  }
  let zero_eff = zero && !minus && prec is None
  push_string_utf8(ctx.out, pad_field(sign, body, width, minus, zero_eff))
}

///|
fn emit_unsigned(
  ctx : Ctx,
  u : UInt64,
  radix : Int32,
  upper : Bool,
  alt : Bool,
  width : Int32?,
  prec : Int32?,
  minus : Bool,
  zero : Bool,
) -> Unit {
  let digits = u.to_string(radix~)
  let mut body = apply_precision(
    if upper {
      digits.to_upper()
    } else {
      digits
    },
    prec,
  )
  let mut prefix = ""
  if alt && radix == 8 && !body.has_prefix("0") {
    body = "0" + body
  }
  if alt && radix == 16 && u != 0 {
    prefix = if upper { "0X" } else { "0x" }
  }
  let zero_eff = zero && !minus && prec is None
  push_string_utf8(ctx.out, pad_field(prefix, body, width, minus, zero_eff))
}

///|
fn emit_float(
  ctx : Ctx,
  conv : Char,
  x : @numfmt.Value,
  width : Int32?,
  prec : Int32?,
  minus : Bool,
  plus : Bool,
  space : Bool,
  zero : Bool,
  alt : Bool,
) -> Unit {
  let body = @numfmt.format_magnitude(
    x,
    conv,
    prec,
    alt,
    float_profile,
    normalized_hex=false,
  )
  let nonfinite = match x {
    @numfmt.Finite(_, _, _) => false
    _ => true
  }
  let sign = if x.is_negative() {
    "-"
  } else if plus {
    "+"
  } else if space {
    " "
  } else {
    ""
  }
  let (prefix, body) = if conv is ('a' | 'A') && !nonfinite {
    (sign + body[:2].to_owned(), body[2:].to_owned())
  } else {
    (sign, body)
  }
  push_string_utf8(
    ctx.out,
    pad_field(prefix, body, width, minus, zero && !minus && !nonfinite),
  )
}

///|
fn emit_b(ctx : Ctx, text : String) -> Unit {
  let chars : Array[Char] = text.iter().collect()
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '\\' {
      let (esc, used) = decode_escape(chars, i, in_b=true)
      match esc {
        Out(chunk) => ctx.out.append(chunk)
        Stop => {
          ctx.stop = true
          return
        }
        Invalid(msg) => {
          ctx.fatal = Some(msg)
          return
        }
      }
      i += used
    } else {
      push_char_utf8(ctx.out, chars[i])
      i += 1
    }
  }
}

///|
/// GNU printf's per-conversion modifier rules, derived empirically:
/// %b and %% take no modifiers; # is limited to o/x/X and floats; the zero
/// flag is invalid for s/c; %c takes no precision.
fn spec_valid(
  conv : Char,
  minus : Bool,
  plus : Bool,
  space : Bool,
  zero : Bool,
  alt : Bool,
  width : Int32?,
  prec : Int32?,
) -> Bool {
  match conv {
    'd' | 'i' | 'u' => !alt
    'o' | 'x' | 'X' | 'e' | 'E' | 'f' | 'F' | 'g' | 'G' | 'a' | 'A' => true
    's' => !zero && !alt
    'c' => !zero && !alt && prec is None
    'b' | 'q' | '%' =>
      !minus &&
      !plus &&
      !space &&
      !zero &&
      !alt &&
      width is None &&
      prec is None
    _ => true
  }
}

///|
/// Field widths allocate real padding, so cap them far below INT_MAX.
let max_width : Int32 = 100000000

///|
/// One pass over the format string; conversions consume arguments from ctx.
fn scan_format(ctx : Ctx, chars : Array[Char]) -> Unit {
  let mut i = 0
  while i < chars.length() {
    if ctx.stop || !(ctx.fatal is None) {
      return
    }
    let c = chars[i]
    if c == '\\' {
      let (esc, used) = decode_escape(chars, i)
      match esc {
        Out(bytes) => ctx.out.append(bytes)
        Stop => {
          ctx.stop = true
          return
        }
        Invalid(msg) => {
          ctx.fatal = Some(msg)
          return
        }
      }
      i += used
      continue
    }
    if c != '%' {
      push_char_utf8(ctx.out, c)
      i += 1
      continue
    }
    let spec_start = i
    let mut j = i + 1
    let mut minus = false
    let mut plus = false
    let mut space = false
    let mut zero = false
    let mut alt = false
    while j < chars.length() {
      match chars[j] {
        '-' => minus = true
        '+' => plus = true
        ' ' => space = true
        '0' => zero = true
        '#' => alt = true
        _ => break
      }
      j += 1
    }
    let mut width : Int32? = None
    if j < chars.length() && chars[j] == '*' {
      let v = match ctx.next_arg() {
        Some(arg) => parse_integer(ctx, arg, unsigned=false)
        None => 0
      }
      // Padding is materialized in memory, so widths are capped well below
      // INT_MAX; GNU would print the gigabytes of spaces instead.
      if v > max_width.to_int64() || v < -max_width.to_int64() {
        ctx.fatal = Some("printf: invalid field width: '\{v}'")
        return
      }
      if v < 0 {
        minus = true
        width = Some((-v).to_int())
      } else {
        width = Some(v.to_int())
      }
      j += 1
    } else {
      let mut w = 0
      let mut any = false
      let digits_start = j
      while j < chars.length() && chars[j] is ('0'..<='9') {
        let d = chars[j].to_int() - 0x30
        if w > (max_width - d) / 10 {
          let sb = StringBuilder()
          for k in digits_start..<chars.length() {
            if !(chars[k] is ('0'..<='9')) {
              break
            }
            sb.write_char(chars[k])
          }
          ctx.fatal = Some("printf: invalid field width: '\{sb}'")
          return
        }
        w = w * 10 + d
        any = true
        j += 1
      }
      if any {
        width = Some(w)
      }
    }
    let mut prec : Int32? = None
    if j < chars.length() && chars[j] == '.' {
      j += 1
      if j < chars.length() && chars[j] == '*' {
        let v = match ctx.next_arg() {
          Some(arg) => parse_integer(ctx, arg, unsigned=false)
          None => 0
        }
        // Precision materializes zeros in memory, so it shares the width cap.
        if v > max_width.to_int64() {
          ctx.fatal = Some("printf: invalid precision: '\{v}'")
          return
        }
        // Any negative precision means the precision is omitted.
        prec = if v < 0 { None } else { Some(v.to_int()) }
        j += 1
      } else {
        let mut p = 0
        let digits_start = j
        while j < chars.length() && chars[j] is ('0'..<='9') {
          let d = chars[j].to_int() - 0x30
          if p > (max_width - d) / 10 {
            let sb = StringBuilder()
            for k in digits_start..<chars.length() {
              if !(chars[k] is ('0'..<='9')) {
                break
              }
              sb.write_char(chars[k])
            }
            ctx.fatal = Some("printf: invalid precision: '\{sb}'")
            return
          }
          p = p * 10 + d
          j += 1
        }
        prec = Some(p)
      }
    }
    if j >= chars.length() {
      ctx.fatal = Some("printf: missing conversion specifier at end of format")
      return
    }
    let conv = chars[j]
    i = j + 1
    if !spec_valid(conv, minus, plus, space, zero, alt, width, prec) {
      let sb = StringBuilder()
      for k in spec_start..<i {
        sb.write_char(chars[k])
      }
      ctx.fatal = Some("printf: \{sb}: invalid conversion specification")
      return
    }
    match conv {
      '%' => ctx.out.push(b'%')
      'd' | 'i' => {
        // A missing argument formats as zero without a diagnostic.
        let n = match ctx.next_arg() {
          Some(arg) => parse_integer(ctx, arg, unsigned=false)
          None => 0
        }
        emit_signed(ctx, n, width, prec, minus, plus, space, zero)
      }
      'u' | 'o' | 'x' | 'X' => {
        let n = match ctx.next_arg() {
          Some(arg) => parse_integer(ctx, arg, unsigned=true)
          None => 0
        }
        let radix = match conv {
          'u' => 10
          'o' => 8
          _ => 16
        }
        emit_unsigned(
          ctx,
          n.reinterpret_as_uint64(),
          radix,
          conv == 'X',
          alt && conv != 'u',
          width,
          prec,
          minus,
          zero,
        )
      }
      's' => {
        // GNU printf measures %s width and precision in bytes.
        let arg = ctx.next_arg().unwrap_or("")
        let bytes : Array[Byte] = []
        push_string_utf8(bytes, arg)
        let limited = match prec {
          Some(p) =>
            if bytes.length() > p {
              bytes[0:p].to_owned()
            } else {
              bytes
            }
          None => bytes
        }
        emit_padded_bytes(ctx.out, limited, width, minus)
      }
      'c' => {
        // GNU printf emits only the first byte of the argument; a missing
        // or empty argument emits one NUL byte.
        let arg = ctx.next_arg().unwrap_or("")
        let bytes : Array[Byte] = []
        push_string_utf8(bytes, arg)
        let first = if bytes.length() > 0 { [bytes[0]] } else { [b'\x00'] }
        emit_padded_bytes(ctx.out, first, width, minus)
      }
      'b' => {
        let arg = ctx.next_arg().unwrap_or("")
        emit_b(ctx, arg)
      }
      'q' =>
        if ctx.next_arg() is Some(arg) {
          push_string_utf8(ctx.out, shell_quote(arg))
        }
      'f' | 'F' | 'e' | 'E' | 'g' | 'G' | 'a' | 'A' => {
        let x = match ctx.next_arg() {
          Some(arg) => parse_float_arg(ctx, arg)
          None => @numfmt.zero()
        }
        emit_float(ctx, conv, x, width, prec, minus, plus, space, zero, alt)
      }
      _ => {
        ctx.fatal = Some("printf: %\{conv}: invalid conversion specification")
        return
      }
    }
  }
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("printf 0.2.2\n")
    return
  }
  let argv = @env.args()[1:]
  if argv.length() > 0 && argv[0] == "--help" {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  let operands = if argv.length() > 0 && argv[0] == "--" {
    argv[1:]
  } else {
    argv
  }
  if operands.is_empty() {
    @stdio.stderr.write(
      "printf: missing operand\nTry 'printf --help' for more information.\n",
    )
    @sys.exit(1)
    return
  }
  let format = operands[0]
  let ctx : Ctx = {
    out: [],
    args: operands[1:].to_owned(),
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
  @stdio.stdout.write(Bytes::from_array(ctx.out))
  for msg in ctx.messages {
    @stdio.stderr.write(msg + "\n")
  }
  match ctx.fatal {
    Some(msg) => {
      @stdio.stderr.write(msg + "\n")
      @sys.exit(1)
      return
    }
    None => ()
  }
  if ctx.exit_error {
    @sys.exit(1)
  }
}
