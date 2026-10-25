///|
async fn main {
  let status = @checksum.run_cksum(@env.args()[1:], command_version)
  if status != 0 {
    @sys.exit(status)
  }
}
