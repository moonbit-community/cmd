///|
// jq 1.8's decimal literal context retains precision independently of the
// evaluator's Double value. These bounds follow its fixed decNumber context.
const StreamDecimalMaxExponent : Int64 = 999999999L

///|
const StreamDecimalMinExponent : Int64 = -1147483646L

///|
fn stream_increment(digits : String) -> String {
  let bytes = @utf8.encode(digits).to_array()
  for index = bytes.length() - 1; index >= 0; index = index - 1 {
    if bytes[index] < b'9' {
      bytes[index] = (bytes[index].to_int() + 1).to_byte()
      return @utf8.decode_lossy(Bytes::from_array(bytes))
    }
    bytes[index] = b'0'
  }
  "1" + @utf8.decode_lossy(Bytes::from_array(bytes))
}

///|
fn stream_number(text : String) -> Json? {
  let sign = if text.has_prefix("-") { "-" } else { "" }
  let unsigned = if text.has_prefix("-") || text.has_prefix("+") {
    text[1:].to_owned()
  } else {
    text
  }
  if unsigned.to_lower() == "nan" {
    return Some(Json::null())
  }
  let maximum = sign + "1.7976931348623157e+308"
  if unsigned.to_lower() == "infinity" || unsigned.to_lower() == "inf" {
    return stream_number_value(maximum)
  }
  let (mantissa, exponent) = match unsigned.to_lower().split_once("e") {
    Some((mantissa, exponent)) => (mantissa.to_owned(), exponent.to_owned())
    None => (unsigned, "0")
  }
  let exp_digits = if exponent.has_prefix("+") || exponent.has_prefix("-") {
    exponent[1:]
  } else {
    exponent[:]
  }
  if exp_digits.is_empty() ||
    !exp_digits.iter().all(char => char >= '0' && char <= '9') {
    return None
  }
  // Beyond the context plus the token length, later decimal-point adjustment
  // cannot bring an exponent back into range. Saturate before arithmetic.
  let margin = mantissa.length().to_int64() + 1L
  let lower = StreamDecimalMinExponent - margin
  let upper = StreamDecimalMaxExponent + margin
  let mut scale = (@string.parse_int64(exponent) catch {
      _ => if exponent.has_prefix("-") { lower } else { upper }
    })
    .max(lower)
    .min(upper)
  let digits = StringBuilder()
  let mut dot = false
  for char in mantissa {
    if char == '.' && !dot {
      dot = true
      continue
    }
    if char < '0' || char > '9' {
      return None
    }
    digits.write_char(char)
    if dot {
      scale -= 1L
    }
  }
  let mut coefficient = digits.to_string().trim_start(chars="0").to_owned()
  if digits.to_string() == "" {
    return None
  }
  if coefficient == "" {
    coefficient = "0"
  }
  if coefficient != "0" &&
    scale + coefficient.length().to_int64() - 1L > StreamDecimalMaxExponent {
    return stream_number_value(maximum)
  }
  if scale < StreamDecimalMinExponent {
    let discard = StreamDecimalMinExponent - scale
    let retain = (coefficient.length().to_int64() - discard).max(0L).to_int()
    let round_up = discard <= coefficient.length().to_int64() &&
      coefficient.code_unit_at(retain) >= '5'
    coefficient = if retain == 0 {
      "0"
    } else {
      coefficient[:retain].to_owned()
    }
    if round_up {
      coefficient = stream_increment(coefficient)
    }
    scale = StreamDecimalMinExponent
  }
  if coefficient == "0" && scale > StreamDecimalMaxExponent {
    scale = StreamDecimalMaxExponent
  }
  let adjusted = scale + coefficient.length().to_int64() - 1L
  let literal = if scale <= 0L && adjusted >= -6L {
    let point = coefficient.length().to_int64() + scale
    if point <= 0L {
      "0." + String::make((-point).to_int(), '0') + coefficient
    } else if point < coefficient.length().to_int64() {
      coefficient[:point.to_int()].to_owned() +
      "." +
      coefficient[point.to_int():].to_owned()
    } else {
      coefficient
    }
  } else {
    coefficient[:1].to_owned() +
    (if coefficient.length() > 1 {
      "." + coefficient[1:].to_owned()
    } else {
      ""
    }) +
    "E" +
    (if adjusted >= 0L { "+" } else { "" }) +
    adjusted.to_string()
  }
  stream_number_value(sign + literal)
}

///|
fn stream_number_value(literal : String) -> Json? {
  try @json.parse(literal, preserve_number_repr=true) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}
