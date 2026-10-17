///|
async fn main {
  @sys.exit(@gzipops.run("gzip", @env.args()[1:], "0.1.1"))
}
