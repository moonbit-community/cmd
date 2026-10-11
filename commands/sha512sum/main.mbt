///|
async fn main {
  let status = @checksum.run(Sha512, @env.args()[1:], command_version)
  if status != 0 {
    @sys.exit(status)
  }
}
