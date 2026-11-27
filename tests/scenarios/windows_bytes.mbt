///|
async fn windows_byte_observe(
  program : String,
  args : Array[String],
  source : String,
  work : String,
  receipts : String,
  input : Bytes,
) -> @harness.RunResult {
  if source == "redirect" {
    let status = @process.run(
      program,
      args,
      stdin=@process.redirect_from_file(work + "/payload"),
      stdout=@process.redirect_to_file(receipts + ".stdout"),
      stderr=@process.redirect_to_file(receipts + ".stderr"),
      cwd=work,
    )
    @fs.write_file(receipts + ".status", status.to_string())
    return {
      status,
      stdout: @fs.read_file(receipts + ".stdout").binary(),
      stderr: @fs.read_file(receipts + ".stderr").binary(),
    }
  }
  let result = @harness.run(program, args, stdin=input, cwd=work)
  @fs.write_file(receipts + ".stdout", result.stdout)
  @fs.write_file(receipts + ".stderr", result.stderr)
  @fs.write_file(receipts + ".status", result.status.to_string())
  result
}
