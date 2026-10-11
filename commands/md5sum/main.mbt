///|
async fn main {
  let status = @checksum.run(Md5, @env.args()[1:], command_version)
  if status != 0 {
    @sys.exit(status)
  }
}
