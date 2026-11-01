///|
// Direct-child observations; no benchmark statistics or coverage claims.
struct Observation {
  status : Int32
  elapsed_us : Double
  first_output_us : Double?
  kernel_peak_rss_bytes : Int64?
  sampled_rss_bytes : Int64
  sampled_temp_bytes : Int64
  sampled_temp_allocated_bytes : Int64
  sampled_temp_files : Int32
  residual_temp_files : Int32
  residual_temp_entries : Int32
  residual_temp_bytes : Int64
  output_bytes : Int64
  timed_out : Bool
} derive(ToJson)

///|
struct Samples {
  mut first : Double?
  mut rss : Int64
  mut temp : Int64
  mut allocated : Int64
  mut files : Int32
  mut complete : Bool
}

///|
async fn tree_size(path : String) -> (Int64, Int32) {
  let mut bytes = 0L
  let mut files = 0
  for name in @fs.readdir(path) {
    let child = path + "/" + name
    match @fs.kind(child, follow_symlink=false) {
      Directory => {
        let (size, count) = tree_size(child)
        bytes += size
        files += count
      }
      Regular => {
        bytes += @fs.file_size(child)
        files += 1
      }
      _ => ()
    }
  }
  (bytes, files)
}

///|
fn first_number(text : String) -> Int64? {
  guard text.split("\n").next() is Some(line) else { return None }
  guard line.split("\t").next() is Some(value) else { return None }
  Some(@string.parse_int64(value.trim())) catch {
    _ => None
  }
}

///|
async fn observe(
  program : String,
  args : Array[String],
  input : String,
  directory : String,
  timeout : Int32,
  kernel~ : Bool = false,
) -> Observation {
  if kernel {
    return observe_kernel(program, args, input, directory)
  }
  @fs.mkdir(directory)
  let effects = directory + "/effects"
  let temporary = directory + "/temporary"
  @fs.mkdir(effects)
  @fs.mkdir(temporary)
  let capture = @fs.create(directory + "/stdout")
  defer capture.close()
  let errors = @process.redirect_to_file(directory + "/stderr")
  defer errors.close()
  let stdin = @process.redirect_from_file(input)
  let (reader, output) = @process.read_from_process()
  defer reader.close()
  let samples : Samples = {
    first: None,
    rss: 0L,
    temp: 0L,
    allocated: 0L,
    files: 0,
    complete: false,
  }
  let started = @bench.monotonic_clock_start()
  let elapsed = Ref(0.0)
  let status = @async.with_timeout_opt(timeout, () => {
    @async.with_task_group() <| group => {
      let child = @process.spawn(
        group,
        program,
        args,
        stdin~,
        stdout=output,
        stderr=errors,
        cwd=effects[:],
        extra_env=Map([
          ("LC_ALL", "C"),
          ("LANG", "C"),
          ("TZ", "UTC"),
          ("TMPDIR", temporary + "/"),
          ("TMP", temporary),
          ("TEMP", temporary),
        ]),
        cancel_handler=@process.hard_cancel(),
      )
      let consume = group.spawn(() => {
        while reader.read_some(max_len=65536) is Some(bytes) {
          if samples.first is None {
            samples.first = Some(@bench.monotonic_clock_end(started))
          }
          capture.write(bytes)
        }
      })
      let sample = group.spawn(() => {
        while !samples.complete {
          let rss = @shell.Cmd("/bin/ps", [
            "-o",
            "rss=",
            "-p",
            child.pid.to_string(),
          ]).output()
          if rss.exit_code() == 0 && first_number(rss.stdout()) is Some(value) {
            samples.rss = samples.rss.max(value * 1024)
          }
          let sizes = tree_size(temporary) catch { _ => (0L, 0) }
          samples.temp = samples.temp.max(sizes.0)
          samples.files = samples.files.max(sizes.1)
          let allocated = @shell.Cmd("/usr/bin/du", ["-sk", temporary]).output()
          if allocated.exit_code() == 0 &&
            first_number(allocated.stdout()) is Some(value) {
            samples.allocated = samples.allocated.max(value * 1024)
          }
          if samples.first is None && tree_size(effects).0 > 0L {
            samples.first = Some(@bench.monotonic_clock_end(started))
          }
          @async.sleep(100)
        }
      })
      let status = child.wait()
      consume.wait()
      elapsed.val = @bench.monotonic_clock_end(started)
      samples.complete = true
      sample.wait()
      status
    }
  })
  let elapsed_us = if status is None {
    @bench.monotonic_clock_end(started)
  } else {
    elapsed.val
  }
  let residual = tree_size(temporary)
  {
    status: status.unwrap_or(-999),
    elapsed_us,
    first_output_us: samples.first,
    kernel_peak_rss_bytes: None,
    sampled_rss_bytes: samples.rss,
    sampled_temp_bytes: samples.temp,
    sampled_temp_allocated_bytes: samples.allocated,
    sampled_temp_files: samples.files,
    residual_temp_files: residual.1,
    residual_temp_entries: @fs.readdir(temporary).length(),
    residual_temp_bytes: residual.0,
    output_bytes: @fs.file_size(directory + "/stdout"),
    timed_out: status is None,
  }
}

///|
async fn observe_kernel(
  program : String,
  args : Array[String],
  input : String,
  directory : String,
) -> Observation {
  @fs.mkdir(directory)
  let effects = directory + "/effects"
  let temporary = directory + "/temporary"
  @fs.mkdir(effects)
  @fs.mkdir(temporary)
  let started = @bench.monotonic_clock_start()
  // Known completed profiles only: the CI step owns the overall deadline.
  let status = @shell.Cmd(
    "/usr/bin/time",
    ["-q", "-f", "%M", "-o", directory + "/rusage.txt", "--", program, ..args],
    cwd=effects,
    env=Map([
      ("LC_ALL", "C"),
      ("LANG", "C"),
      ("TZ", "UTC"),
      ("TMPDIR", temporary + "/"),
      ("TMP", temporary),
      ("TEMP", temporary),
    ]),
    stdin=FromFile(input),
    stdout=ToFile(directory + "/stdout"),
    stderr=ToFile(directory + "/stderr"),
  ).status()
  let elapsed_us = @bench.monotonic_clock_end(started)
  let rss = @string.parse_int64(
    @fs.read_file(directory + "/rusage.txt").text().trim(),
  )
  let residual = tree_size(temporary)
  {
    status,
    elapsed_us,
    first_output_us: None,
    kernel_peak_rss_bytes: Some(rss * 1024L),
    sampled_rss_bytes: 0L,
    sampled_temp_bytes: 0L,
    sampled_temp_allocated_bytes: 0L,
    sampled_temp_files: 0,
    residual_temp_files: residual.1,
    residual_temp_entries: @fs.readdir(temporary).length(),
    residual_temp_bytes: residual.0,
    output_bytes: @fs.file_size(directory + "/stdout"),
    timed_out: false,
  }
}
