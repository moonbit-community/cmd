///|
priv enum Column {
  Pid(Int32)
  Signed(Int32, Int32)
  Nice
  State
  Command
}

///|
fn column(name : String) -> Column raise {
  match name {
    "pid" => Pid(-1)
    "ppid" => Pid(1)
    "pgrp" | "pgid" => Pid(2)
    "sess" | "session" | "sid" => Pid(3)
    "tpgid" => Pid(5)
    "ni" | "nice" => Nice
    "nlwp" | "thcount" => Signed(17, 4)
    "s" | "state" => State
    "comm" | "ucmd" | "ucomm" => Command
    _ => raise Failure::Failure("unsupported output field: " + name)
  }
}

///|
pub async fn rows(pid : UInt32, formats : Array[String]) -> String? {
  let columns = []
  for format in formats {
    for spec in format.split(",") {
      guard spec.strip_suffix("=") is Some(name) else {
        raise Failure::Failure("select no-heading fields with -o FIELD=")
      }
      columns.push(column(name.to_owned()))
    }
  }
  let stat = @fs.read_text("/proc/" + pid.to_string() + "/stat") catch {
    @os_error.OsError(NotFound, ..) => return None
    err => raise err
  }
  guard stat.split_once(" (") is Some((pid_field, rest)) &&
    rest.rev_split_once(") ") is Some((comm, text)) else {
    raise Failure::Failure("invalid process stat record")
  }
  let fields = text.trim().split(" ").to_array()
  guard fields.length() >= 39 else {
    raise Failure::Failure("incomplete process stat record")
  }
  let pid_width = if columns.any(col => col is Pid(_)) {
    @fs.read_text("/proc/sys/kernel/pid_max").trim().length().max(5)
  } else {
    0
  }
  let rendered = []
  for i, col in columns {
    let value = match col {
      Pid(index) =>
        (if index < 0 { pid_field } else { fields[index] })
        .to_owned()
        .pad_start(pid_width, ' ')
      Signed(index, width) => fields[index].to_owned().pad_start(width, ' ')
      Nice =>
        (if fields[38] is ("0" | "3") { fields[16].to_owned() } else { "-" }).pad_start(
          3, ' ',
        )
      State => fields[0].to_owned()
      Command => {
        guard comm.iter().all(ch => ch >= ' ' && ch <= '~') else {
          raise Failure::Failure(
            "process name is outside the printable ASCII profile",
          )
        }
        if i + 1 == columns.length() {
          comm.to_owned()
        } else {
          comm[:comm.length().min(15)].to_owned().pad_end(15, ' ')
        }
      }
    }
    rendered.push(value)
  }
  Some(rendered.join(" ") + "\n")
}
