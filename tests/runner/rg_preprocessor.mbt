///|
// Portable observation fixture, invoked only through an explicitly selected --pre.
async fn run_rg_preprocessor(mode : String, args : ArrayView[String]) -> Unit {
  guard args is [path] && @fs.exists(path) else {
    fail("preprocessor argv/cwd was not preserved")
  }
  match mode {
    "copy" => {
      let chunk = FixedArray::make(7, b'\x00')
      for ;; {
        let count = @stdio.stdin.read(chunk)
        if count == 0 {
          return
        }
        @stdio.stdout.write(Bytes::from_array(chunk[:count]))
      }
    }
    "partial-failure" => {
      @stdio.stdout.write(b"alpha\n")
      @stdio.stderr.write(b"preprocessor failed\n")
      @sys.exit(3)
    }
    "stream" => {
      let chunk = Bytes::makei(8192, i => b"alpha\n"[i % 6])
      for ;; {
        @stdio.stdout.write(chunk)
      }
    }
    _ => fail("unknown rg preprocessor fixture")
  }
}
