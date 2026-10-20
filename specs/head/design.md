# Design: head

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the arguments
into `Options`, handles `--help` and `--version`, and calls
`commands.head.run_head`. `run_head` reads each operand whole, picks the part
to keep with pure functions (`head_lines`, `bytes_kept`) and writes it, with a
header when there are several operands.

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses (usage errors are status 1, as in GNU head) |
| `source/cli/count.loup` | `parse_size` (digits, `+`, blanks, multiplier suffixes, overflow), `parse_count` (leading `-`, GNU's messages), `quote_arg` |
| `source/cli/args.loup` | `Options`, `UsageError`, `match_long`, `is_obsolete_count`, `parse_args` |
| `source/cli/usage.loup` | `usage()` help text, `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, run the command, map exceptions to status 1 |
| `source/cli/output.loup` | `is_utf8`, `print_bytes` (exact byte output, through C's `putchar` when needed) |
| `source/commands/head.loup` | `head_lines`, `bytes_kept`, `header`, `show_headers`, `quote_name`, `io_reason`, `run_head` |

## Parsing

`parse_args` first looks for GNU's obsolete form in the first argument
(`-5`, `-5c`, `-2kq`), then walks the rest as getopt_long does: short options
in groups, where `-n`/`-c` take the rest of the group or the next argument;
long options matched exactly or by a unique prefix, with `=VALUE` or the next
argument; operands collected in order; `--` ends the options. A count error
comes back as a `UsageError` with `try_help = false`, because GNU head prints
no "Try" line after a bad number.

## Selecting the output

- Lines: `head_lines` splits the text on the delimiter (`\n`, or NUL under
  `-z`), counts a final piece without a delimiter as a line, and joins the
  first N pieces (or all but the last N) back with the delimiter. Native
  `split` and `join` work on bytes, so the kept lines are byte for byte the
  input, whatever it holds.
- Bytes: `run_head` reads the operand as `bytes`, `bytes_kept` gives how many
  to keep, and the slice is taken in `run_head` itself (a native build
  crashes when a function returns `bytes`; see NATIVE-NOTES).

## Writing bytes

A Loup string can only be built from whole UTF-8 characters, so a byte slice
that ends inside a character, or binary data, has no string form:
`bytes.decode()` would replace the broken sequence with U+FFFD. `print_bytes`
prints `decode()` when `is_utf8` says the slice is well-formed, and otherwise
writes each byte with C's `putchar` through `extern native "c"`, then
`fflush(NULL)` so that later `print`s stay in order. Writing to `/dev/stdout`
with `writeBytes` is not an option: it reopens the file with truncation.

## Differences from GNU head

- Each operand is read whole before anything is printed (no streaming reads in
  Loup 1.26.0, ROADMAP T2), so head on an endless input such as
  `head -c 10 /dev/zero` never finishes, and memory grows with the input.
- Counts must be below 2^63; GNU accepts up to 2^64 - 1 (`-c 8E` is "too
  large" here).
- Messages quote as GNU does in the C locale (`'x'`, never `‘x’`).
- An operand that exists but cannot be read stops the native binary with the
  runtime's own `IoError` message and status 1 (T1: no `stat()` to check
  permissions first; the native runtime cannot raise a catchable `IoError`).
- Raw byte output (`-c` cutting a character, or binary data) uses C, so under
  `loup run` (`make run`) it stops with "unsupported instruction"; the native
  binary handles it.
- The `Z`, `Y`, `R` and `Q` suffixes always overflow, as in GNU, but the help
  text lists only up to `E`.
- `--version` prints one line.

## Error handling

`run_head` checks `exists` and `isDir` before reading. A missing operand gives
`head: cannot open 'NAME' for reading: No such file or directory`; a
directory gets its header and `head: error reading 'NAME': Is a directory`.
Both set status 1 and the loop moves on. File names are quoted as GNU's
`quoteaf` does for ordinary names (`quote_name`); counts as its `quote`
(`quote_arg`).

## Testing

- `tests/count_test.loup`: numbers, suffixes, invalid text, overflow, messages.
- `tests/args_test.loup`: options, groups, the obsolete form, headers,
  operands, usage errors and which of them get the "Try" line.
- `tests/head_test.loup`: `head_lines` (first and all-but-last, partial last
  line, NUL), `bytes_kept`, headers, quoting.
- `tests/output_test.loup`: `is_utf8` on valid and malformed sequences.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary on files and standard input, compared
  byte for byte, including counts that cut a UTF-8 character, binary output
  into a file, a pipe and between other writers, headers, errors and statuses.
