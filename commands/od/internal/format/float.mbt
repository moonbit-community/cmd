///|
priv enum FloatKind {
  Half
  BFloat
  Single
  Double
  Extended80
}

///|
fn FloatKind::profile(self : FloatKind) -> @numfmt.Profile {
  match self {
    Half | BFloat | Single => @numfmt.Binary32
    Double => @numfmt.Binary64
    Extended80 => @numfmt.Extended80
  }
}

///|
fn FloatKind::width(self : FloatKind) -> Int32 {
  match self {
    Half | BFloat | Single => 15
    Double => 24
    Extended80 => 29
  }
}

///|
fn FloatKind::decode_profile(self : FloatKind) -> @numfmt.Profile {
  match self {
    Half => @numfmt.Binary16
    BFloat => @numfmt.BFloat16
    Single => @numfmt.Binary32
    Double => @numfmt.Binary64
    Extended80 => @numfmt.Extended80
  }
}

///|
fn float_at(
  data : Bytes,
  start : Int32,
  size : Int32,
  big : Bool,
  kind : FloatKind,
) -> @numfmt.Value {
  @numfmt.decode(
    data[start:Int32::min(start + size, data.length())],
    kind.decode_profile(),
    big_endian=big,
  )
}
