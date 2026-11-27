///|
fn report(
  text : String,
  divisor : Int64,
  wide : Bool,
  total : Bool,
) -> String raise {
  let fields : Map[String, Int64] = Map([])
  for line in text.split("\n") {
    if line.split_once(":") is Some((key, value)) &&
      value.trim().strip_suffix(" kB") is Some(kib) {
      fields[key.to_owned()] = @string.parse_int64(kib)
    }
  }
  let get = fn(key : String) raise {
    fields
    .get(key)
    .unwrap_or_else(() => {
      raise Failure::Failure("missing memory statistic " + key)
    })
  }
  let mem = get("MemTotal")
  let available = get("MemAvailable")
  let free = get("MemFree")
  let buffers = get("Buffers")
  let cache = get("Cached") + get("SReclaimable")
  let swap = get("SwapTotal")
  let swap_free = get("SwapFree")
  let row = fn(name : String, values : Array[Int64]) {
    name.pad_end(9, ' ') +
    values
    .map(value => (value * 1024L / divisor).to_string().pad_start(11, ' '))
    .join(" ") +
    "\n"
  }
  let header = "               total        used        free      shared " +
    (if wide { "    buffers       cache" } else { " buff/cache" }) +
    "   available\n"
  let memory = [mem, mem - available, free, get("Shmem")]
  if wide {
    memory.push(buffers)
    memory.push(cache)
  } else {
    memory.push(buffers + cache)
  }
  memory.push(available)
  header +
  row("Mem:", memory) +
  row("Swap:", [swap, swap - swap_free, swap_free]) +
  (if total {
    row("Total:", [
      mem + swap,
      mem - available + swap - swap_free,
      free + swap_free,
    ])
  } else {
    ""
  })
}
