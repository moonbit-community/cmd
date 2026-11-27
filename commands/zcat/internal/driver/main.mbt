///|
pub async fn run_main() -> Unit {
  @env.exit(@gzipops.run("zcat", @env.args()[1:], MODULE_VERSION))
}
