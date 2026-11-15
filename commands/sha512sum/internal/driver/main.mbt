///|
pub async fn run_main() -> Unit {
  let status = @checksum.run(Sha512, @env.args()[1:], MODULE_VERSION)
  if status != 0 {
    @sys.exit(status)
  }
}
