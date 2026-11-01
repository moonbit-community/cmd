///|
// Exhausted or unsupported engines remain disabled for this matcher. They
// must not be rebuilt on the next record or resume from a partial result.
priv enum EngineCache[T] {
  Uninitialized
  Disabled
  Ready(T)
}

///|
fn[T] engine_cache(engine : T?) -> EngineCache[T] {
  match engine {
    Some(engine) => Ready(engine)
    None => Disabled
  }
}
