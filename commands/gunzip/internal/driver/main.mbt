///|
pub async fn run_main() -> Unit {
  @sys.exit(@gzipops.run("gunzip", @env.args()[1:], MODULE_VERSION))
}
