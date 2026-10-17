///|
fn validate_native_only_selection(
  backend : String,
  all : Bool,
  native_only : Bool,
) -> Unit raise {
  guard !native_only || (backend == "native" && all) else {
    fail("--native-only requires --backend native --all")
  }
}

///|
/// Native-only execution complements pair mode without repeating dual targets.
fn package_all_selected(
  entry : @registry.RegistryEntry,
  backend : String,
  host : String,
  native_only : Bool,
) -> Bool {
  entry.implementation == "package-test" &&
  platform_applies(entry.platforms, host) &&
  (if native_only {
    backend == "native" && entry.required_backends == ["native"]
  } else if backend == "pair" {
    entry.requires_backend_pair()
  } else {
    entry.required_backends.contains(backend)
  })
}
