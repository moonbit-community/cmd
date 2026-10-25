///|
async fn main {
  let status = @checksum.run(Sha256, @env.args()[1:], "0.2.2")
  if status != 0 {
    @sys.exit(status)
  }
}
