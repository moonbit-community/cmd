///|
/// A candidate path for matching.
///
/// All glob matching in this package operates on `Candidate` values.
/// Constructing candidates has a very small cost associated with it, so
/// callers may find it beneficial to amortize that cost when matching a single
/// path against multiple globs or sets of globs.
pub struct Candidate {
  priv path : Bytes
  priv path_arr : FixedArray[Byte]
  priv basename : Bytes
  priv ext : Bytes
}

///|
/// Create a new candidate for matching from the given path.
///
/// The path is encoded as UTF-8 before matching.
pub fn Candidate::new(path : String) -> Candidate {
  // Paths are OS strings: match their original bytes.
  Candidate::from_bytes(@osstr.encode(path))
}

///|
/// Create a new candidate for matching from the given path as a sequence
/// of bytes.
///
/// Generally speaking, this routine expects the bytes to be
/// _conventionally_ UTF-8. It is legal for the byte sequence to contain
/// invalid UTF-8. However, if the bytes are in some other encoding that
/// isn't ASCII compatible (for example, UTF-16), then the results of
/// matching are unspecified.
pub fn Candidate::from_bytes(path : Bytes) -> Candidate {
  let path = normalize_path(path)
  let basename = file_name(path).unwrap_or(b"")
  let ext = file_name_ext(basename).unwrap_or(b"")
  { path, path_arr: path.to_fixedarray(), basename, ext, }
}

///|
pub impl Debug for Candidate with fn to_repr(self) {
  @debug.Repr::record({
    "path": @debug.Repr::string(lossy(self.path)),
    "basename": @debug.Repr::string(lossy(self.basename)),
    "ext": @debug.Repr::string(lossy(self.ext)),
  })
}

///|
fn lossy(bs : Bytes) -> String {
  @utf8.decode_lossy(bs)
}
