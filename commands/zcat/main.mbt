///|
async fn main {
  @sys.exit(@gzipops.run("zcat", @env.args()[1:], "0.1.2"))
}
