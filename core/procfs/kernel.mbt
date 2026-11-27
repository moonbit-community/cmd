///|
/// Read the kernel's UTS fields in the running Linux namespace.
pub(all) enum UtsField {
  System
  Node
  Release
  Version
}

///|
/// Read one complete line from Linux procfs. The runtime controls filesystem access.
pub async fn kernel_field(field : UtsField) -> String {
  guard @async.platform is Linux else {
    raise Failure::Failure("kernel field requires Linux procfs")
  }
  let name = match field {
    System => "ostype"
    Node => "hostname"
    Release => "osrelease"
    Version => "version"
  }
  let value = @fs.read_text("/proc/sys/kernel/" + name)
  guard value.strip_suffix("\n") is Some(line) else {
    raise Failure::Failure("incomplete kernel field " + name)
  }
  line.to_owned()
}
