///|
async fn main {
  @sys.exit(@gzipops.run("gunzip", @env.args()[1:], "0.1.3"))
}
