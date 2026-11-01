///|
async fn main {
  let options : Map[String, String] = Map([])
  let args = @env.args()[1:]
  for index = 0; index < args.length(); index = index + 2 {
    guard index + 1 < args.length() else { fail("option requires a value") }
    guard [
        "--report-dir", "--wasm-root", "--moonrun", "--oracle-bin", "--commands",
        "--sizes", "--long-record", "--distribution", "--timeout-ms", "--kernel-rss",
      ].contains(args[index]) &&
      !options.contains(args[index]) else {
      fail("unknown or duplicate resource option: " + args[index])
    }
    options[args[index]] = args[index + 1]
  }
  let directory = options.get("--report-dir").unwrap()
  let wasm = @fs.realpath(options.get("--wasm-root").unwrap())
  let moonrun = @fs.realpath(options.get("--moonrun").unwrap())
  let oracle = @fs.realpath(options.get("--oracle-bin").unwrap())
  let commands = options
    .get("--commands")
    .unwrap_or(
      "rev,strings,split,csplit,tac,column,sort,grep,gzip,diff,cut,uniq,wc",
    )
    .split(",")
    .map(value => value.to_owned())
    .collect()
  let seen : Set[String] = Set([])
  for command in commands {
    guard [
        "rev", "strings", "split", "csplit", "tac", "column", "sort", "grep", "gzip",
        "diff", "cut", "uniq", "wc",
      ].contains(command) &&
      !seen.contains(command) else {
      fail("unknown, empty or duplicate resource command: " + command)
    }
    seen.add(command)
  }
  let sizes : Array[Int64] = []
  for
    value in options
    .get("--sizes")
    .unwrap_or("8388608,67108864,536870912")
    .split(",") {
    let size = @string.parse_int64(value)
    guard size > 0 else { fail("resource sizes must be positive") }
    sizes.push(size)
  }
  let long_option = options.get("--long-record").unwrap_or("false")
  guard ["true", "false"].contains(long_option) else {
    fail("--long-record must be true or false")
  }
  let long = long_option == "true"
  let distribution = options.get("--distribution").unwrap_or("ascii")
  let literal = distribution.has_prefix("literal-")
  guard [
    "ascii", "mixed-synthetic", "literal-shared", "literal-diverse", "literal-sparse",
    "literal-budget",
  ].contains(distribution) else {
    fail("unknown resource distribution")
  }
  guard !literal || commands == ["grep"] else {
    fail("literal distributions require grep only")
  }
  let timeout = @string.parse_int(
    options.get("--timeout-ms").unwrap_or("900000"),
  )
  guard timeout > 0 else { fail("resource timeout must be positive") }
  let rss_mode = options.get("--kernel-rss").unwrap_or("sampled")
  guard rss_mode == "sampled" || rss_mode == "linux" else {
    fail("--kernel-rss must be linux")
  }
  let kernel = rss_mode == "linux"
  @fs.mkdir(directory, recursive=true, allow_exist=false)
  let root = @fs.realpath(directory)
  let metadata : Json = {
    "kind": "direct-wasm-resource-observation",
    "sample_interval_ms": if kernel {
      0
    } else {
      100
    },
    "measurement": if kernel {
      "Linux GNU time %M reports kernel ru_maxrss in KiB, converted to bytes; file redirects retain byte/effect comparison; first output and sampled fields are unavailable; observer and time supervisor are outside candidate RSS"
    } else {
      "monotonic stdout first-read/elapsed; named first-output uses polling; RSS and temporary logical/allocated disk are sampled lower bounds; sampling interval includes host observer execution; observer process and native oracle are outside candidate RSS"
    },
    "timeout": if kernel {
      "known completed profiles have no per-row deadline; the CI step overall deadline stops the run and may leave partial reports or temporary files"
    } else {
      "direct child is hard-canceled and reaped; abrupt termination does not promise guest temporary cleanup"
    },
    "kernel_rss": kernel,
    "wasm_root": wasm,
    "moonrun": moonrun,
    "oracle_bin": oracle,
    "distribution": distribution,
    "blind_holdout": false,
    "general_performance_acceptance": false,
    "evidence_role": "synthetic-resource-regression",
    "record_keys": if literal {
      "all a collision misses or all Z sparse misses; sixteen fixed patterns with common suffix; one-MiB records unless long-record is selected"
    } else {
      "deterministic varying decimal keys; legacy mixed-synthetic widths7/89/4097/65537/128 with NUL/0xff on byte profiles; diff and csplit select ordinary80 or short-byte-dominant mixed32/64/96/128/512/4096 ASCII content modes"
    },
    "command_specific_overrides": "diff selects distinct-equal, sparse interior insert/delete and distributed interior edit modes; csplit selects repeated interior SECTION boundaries; these content modes use many short records; long-record additionally retains a separately named single-record-control control for each command",
  }
  @fs.write_file(root + "/metadata.json", metadata.stringify(indent=2))
  let summary = @fs.create(root + "/summary.jsonl")
  defer summary.close()
  let mut failures = 0
  for size in sizes {
    let input = root + "/input-" + size.to_string()
    let changed = input + ".changed"
    let mut last_record = -1L
    let mut last_binary = false
    let mut last_shape = ""
    let mut content_features : ContentInput? = None
    for command in commands {
      let regimes = if command == "diff" {
        [
          "distinct-equal-content", "sparse-interior-insert-delete", "distributed-interior-edits",
        ]
      } else if command == "csplit" {
        ["repeated-interior-sections"]
      } else {
        ["legacy-command-profile"]
      }
      if long && (command == "diff" || command == "csplit") {
        regimes.push("single-record-control")
      }
      for regime in regimes {
        let single_record = regime == "single-record-control"
        let content = (command == "diff" || command == "csplit") &&
          !single_record
        let record = if content {
          80L
        } else if long {
          size
        } else if literal {
          1048576L
        } else {
          80L
        }
        let mixed = !single_record &&
          distribution == "mixed-synthetic" &&
          (content || !long)
        let binary = !single_record &&
          distribution == "mixed-synthetic" &&
          command != "rev" &&
          !content
        let shape = if single_record {
          "single-record-control"
        } else if command == "csplit" {
          "interior-sections"
        } else if command == "diff" {
          "short-content"
        } else {
          "legacy-profile"
        }
        if record != last_record || binary != last_binary || shape != last_shape {
          if content {
            content_features = Some(
              write_content_input(input, size, mixed, command == "csplit"),
            )
          } else {
            content_features = None
            write_input(
              input,
              size,
              record,
              mixed,
              binary,
              literal=if literal { distribution } else { "" },
            )
          }
          last_record = record
          last_binary = binary
          last_shape = shape
        }
        let content_recipe : Json = if single_record {
          if command == "diff" {
            let source = @fs.open(input, mode=ReadOnly)
            defer source.close()
            let right = @fs.create(changed)
            defer right.close()
            copy_content_range(source, right, 0L, size)
            right.write_at(b"x", position=0L)
          }
          {
            "regime": regime,
            "evidence_role": "legacy-single-record-stress",
            "record_layout": "one unbroken ASCII payload with a final LF",
            "source_bytes": size.to_string(),
            "same_file_identity": if command == "diff" {
              Json(false)
            } else {
              Json::null()
            },
            "input_transport": if command == "diff" {
              "distinct-named-regular-files"
            } else {
              "redirected-regular-file"
            },
            "comparison_regime": if command == "diff" {
              "byte-zero replacement in distinct regular files"
            } else {
              "first-record /^/ boundary; empty part-00 plus full-source part-01"
            },
            "independent_effect_check": if command == "csplit" {
              "part-00 is empty and part-01 equals the complete source"
            } else {
              "source/right hashes checked before and after both processes"
            },
          }
        } else if command == "diff" {
          write_content_diff(input, changed, content_features.unwrap(), regime)
        } else if command == "csplit" {
          let features = content_features.unwrap()
          guard features.section_offsets.length() >= 2 else {
            fail("resource csplit needs at least two interior SECTION markers")
          }
          {
            "regime": regime,
            "observed_source": features,
            "expected_fragments": features.section_offsets.length() + 1,
            "final_tail_bytes": (size -
            features.section_offsets[features.section_offsets.length() - 1]).to_string(),
            "independent_effect_check": "each named fragment equals its complete declared source interval",
          }
        } else {
          Json::null()
        }
        let input_hash = resource_sha256(input)
        let changed_hash = if command == "diff" {
          Some(resource_sha256(changed))
        } else {
          None
        }
        if command == "diff" && regime == "distinct-equal-content" {
          guard changed_hash == Some(input_hash) &&
            @fs.realpath(input) != @fs.realpath(changed) else {
            fail(
              "equal diff inputs must have equal bytes and distinct file paths",
            )
          }
        } else if command == "diff" {
          guard changed_hash != Some(input_hash) else {
            fail("edited resource diff inputs must differ")
          }
        }
        let directory = root +
          "/" +
          command +
          "-" +
          size.to_string() +
          (if content || single_record { "-" + regime } else { "" })
        @fs.mkdir(directory)
        let input_identity : Json = {
          "source_path": input,
          "source_bytes": @fs.file_size(input).to_string(),
          "source_sha256": input_hash,
          "right_path": if command == "diff" {
            Json(changed)
          } else {
            Json::null()
          },
          "right_bytes": if command == "diff" {
            Json(@fs.file_size(changed).to_string())
          } else {
            Json::null()
          },
          "right_sha256": changed_hash,
          "requested_long_record": long,
          "actual_many_short_records": content,
          "single_record_record_control": single_record,
          "actual_single_record": single_record || (!content && long),
          "recipe": content_recipe,
        }
        @fs.write_file(
          directory + "/input-identities.json",
          input_identity.stringify(indent=2),
        )
        println(
          "resource start \{command} regime=\{regime} bytes=\{size} record=\{record} distribution=\{distribution}",
        )
        let argv = if single_record && command == "csplit" {
          ["-s", "-f", "part-", "-", "/^/"]
        } else if literal {
          let result = ["-F", "-c"]
          let length = if distribution == "literal-budget" { 256 } else { 32 }
          let marker = if distribution == "literal-shared" { 28 } else { 0 }
          for number in 0..<16 {
            let pattern = Bytes::makei(length, index => {
              if index == marker {
                (98 + number).to_byte()
              } else {
                b'a'
              }
            })
            result.append(["-e", @utf8.decode(pattern)])
          }
          result
        } else {
          arguments(command, input, changed, binary)
        }
        let candidate = observe(
          moonrun,
          [wasm + "/cli/" + command + "/" + command + ".wasm", "--", ..argv],
          input,
          directory + "/candidate",
          timeout,
          kernel~,
        )
        guard resource_sha256(input) == input_hash &&
          (
            changed_hash is None ||
            Some(resource_sha256(changed)) == changed_hash
          ) else {
          fail(
            "resource candidate changed a shared input; refusing to run the oracle on different bytes",
          )
        }
        let reference = observe(
          oracle + "/" + command,
          argv,
          input,
          directory + "/oracle",
          timeout,
          kernel~,
        )
        guard resource_sha256(input) == input_hash &&
          (
            changed_hash is None ||
            Some(resource_sha256(changed)) == changed_hash
          ) else {
          fail("resource oracle changed a shared input")
        }
        let expected = if (
            command == "diff" && regime != "distinct-equal-content"
          ) ||
          literal {
          1
        } else {
          0
        }
        let mut same = !candidate.timed_out &&
          !reference.timed_out &&
          candidate.status == expected &&
          reference.status == expected &&
          @fs.file_size(directory + "/candidate/stderr") == 0L &&
          @fs.file_size(directory + "/oracle/stderr") == 0L
        if command == "gzip" && same {
          same = decode(
              oracle + "/gzip",
              directory + "/candidate/stdout",
              directory + "/decoded-candidate",
            ) &&
            decode(
              oracle + "/gzip",
              directory + "/oracle/stdout",
              directory + "/decoded-oracle",
            ) &&
            equal_files(input, directory + "/decoded-candidate") &&
            equal_files(input, directory + "/decoded-oracle")
        } else if same {
          same = equal_files(
            directory + "/candidate/stdout",
            directory + "/oracle/stdout",
          )
        }
        same = same &&
          equal_effects(
            directory + "/candidate/effects",
            directory + "/oracle/effects",
          ) &&
          candidate.residual_temp_files == 0 &&
          candidate.residual_temp_entries == 0
        if command == "csplit" && same {
          same = candidate.output_bytes == 0L && reference.output_bytes == 0L
          if single_record {
            same = same &&
              single_record_fragments_match(
                input,
                directory + "/candidate/effects",
              ) &&
              single_record_fragments_match(
                input,
                directory + "/oracle/effects",
              )
          } else {
            let features = content_features.unwrap()
            same = same &&
              content_fragments_match(
                input,
                directory + "/candidate/effects",
                features,
              ) &&
              content_fragments_match(
                input,
                directory + "/oracle/effects",
                features,
              )
          }
        }
        if command == "diff" && regime == "distinct-equal-content" && same {
          same = candidate.output_bytes == 0L && reference.output_bytes == 0L
        } else if command == "diff" && same {
          same = candidate.output_bytes > 0L && reference.output_bytes > 0L
        }
        if command == "diff" && same {
          same = @fs.readdir(directory + "/candidate/effects").is_empty() &&
            @fs.readdir(directory + "/oracle/effects").is_empty()
        }
        let result : Json = {
          "command": command,
          "regime": regime,
          "bytes": size.to_string(),
          "record_bytes": if mixed {
            if content {
              "mixed-short32/64/96/128/512/4096"
            } else {
              "legacy-mixed7/89/4097/65537/128"
            }
          } else {
            record.to_string()
          },
          "distribution": distribution,
          "actual_distribution": if single_record {
            "ascii-single-record"
          } else {
            distribution
          },
          "single_record_record_control": single_record,
          "binary_markers": binary,
          "expected_status": expected,
          "input_identities": input_identity,
          "input_hashes_unchanged": true,
          "args": argv,
          "candidate": candidate,
          "oracle": reference,
          "bytes_status_effects_equal": same,
        }
        @fs.write_file(directory + "/result.json", result.stringify(indent=2))
        summary.write(result.stringify() + "\n")
        println(
          "resource done \{command} bytes=\{size} equal=\{same} rss=\{candidate.sampled_rss_bytes} temp=\{candidate.sampled_temp_bytes}",
        )
        if same {
          for side in ["candidate", "oracle"] {
            @fs.remove(directory + "/" + side + "/stdout")
            @fs.rmdir(directory + "/" + side + "/effects", recursive=true)
          }
          if command == "gzip" {
            @fs.remove(directory + "/decoded-candidate")
            @fs.remove(directory + "/decoded-oracle")
          }
        } else {
          failures += 1
        }
      }
    }
    @fs.remove(input)
    if @fs.exists(changed) {
      @fs.remove(changed)
    }
  }
  println("resource completed failures=\{failures}")
  @sys.exit(if failures == 0 { 0 } else { 1 })
}
