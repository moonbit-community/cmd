///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Check if character is digit
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// Check if character is letter or underscore
fn is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
/// Check if character is alphanumeric or underscore
fn is_alnum(c : Char) -> Bool {
  is_alpha(c) || is_digit(c)
}
