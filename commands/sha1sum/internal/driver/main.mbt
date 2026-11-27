///|
pub async fn run_main() -> Unit {
  let status = @checksum.run(Sha1, @env.args()[1:], MODULE_VERSION)
  if status != 0 {
    @env.exit(status)
  }
}
