///|
pub async fn run_main() -> Unit {
  @sys.exit(@gzipops.run("zcat", @env.args()[1:], MODULE_VERSION))
}
