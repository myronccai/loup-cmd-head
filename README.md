# loup-cmd-head

GNU `head` recreated in [Loup](https://code-craft.ai/references/loup): print
the first lines or bytes of files, or all but the last ones, with file-name
headers and GNU's number syntax.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                       # native binary: build/head
make ci                          # check, unit tests, build, end-to-end tests
make run ARGS="-n 3 README.md"   # run from source with loup run
```

```text
$ build/head -n 3 numbers.txt
1
2
3
$ build/head -n -2 names.txt
Ann
Bob
$ build/head -3 names.txt numbers.txt
==> names.txt <==
Ann
Bob
Cy

==> numbers.txt <==
1
2
3
$ build/head -c 4 word.txt | od -An -c
   c   a   f 303
$ build/head -c 1KiB numbers.txt | wc -c
292
$ build/head names.txt missing.txt; echo "exit $?"
==> names.txt <==
Ann
Bob
Cy
Dee
head: cannot open 'missing.txt' for reading: No such file or directory
exit 1
$ build/head -n 3x names.txt; echo "exit $?"
head: invalid number of lines: '3x'
exit 1
$ build/head --version
head (loup-cmd-head) 0.1.0
```

With no FILE, or when FILE is `-`, head reads standard input. The output is
the input's own bytes: `-c 4` above stops in the middle of `é`, as GNU head
does.

| Option | Meaning |
|---|---|
| `-n N`, `--lines=N` | print the first N lines (default 10) |
| `-n -N` | print all but the last N lines |
| `-c N`, `--bytes=N` | print the first N bytes |
| `-c -N` | print all but the last N bytes |
| `-q`, `--quiet`, `--silent` | never print `==> NAME <==` headers |
| `-v`, `--verbose` | always print headers (by default only for several files) |
| `-z`, `--zero-terminated` | lines end with NUL, not newline |
| `-N`, `-Nc`, `-Nkq`, ... | GNU's obsolete count, only as the first argument |

N may start with `+` and end in a multiplier: `b` 512, `K`/`k`/`KiB` 1024,
`kB` 1000, and likewise `M`, `MB`, `G`, `GB`, `T`, `P`, `E`. Short options
combine (`-qn5`), options may follow file names, `--` ends the options, and
long options may be shortened to any unique prefix (`--li=5`).

Exit status: `0` on success; `1` if any operand could not be read or the
command line was invalid (GNU head uses `1` for both).

## Differences from GNU head

- Each file is read whole before anything is printed (Loup 1.26.0 has no
  streaming reads), so an endless input such as `head -c 10 /dev/zero` never
  finishes, and memory grows with the input.
- Counts must be below 2^63; GNU accepts up to 2^64 - 1, so `-c 8E` is
  "Value too large" here.
- Messages always quote like GNU in the C locale (`'x'`, not `‘x’`).
- A file that exists but cannot be read (no read permission) stops the
  native binary with the runtime's message, e.g.
  `IoError: read_text failed on 'secret': Permission denied (os error 13)`,
  and status 1; later operands are not read. Missing files and directories
  are reported as GNU does.
- Bytes that are not whole UTF-8 characters (a `-c` count that cuts a
  character, or binary data) are written through C's `putchar` with
  `extern native "c"`, because a Loup string cannot hold them. `loup run`
  (`make run`) cannot call C and stops there with
  `unsupported instruction`; the native binary is exact.
- `--version` prints a single line.

## Layout

```text
source/main.loup             # entry point
source/appinfo.loup          # name, version, exit statuses
source/cli/count.loup        # GNU number syntax: suffixes, overflow, messages
source/cli/args.loup         # GNU getopt-style parsing, obsolete -N form
source/cli/usage.loup        # --help and --version text
source/cli/app.loup          # run(): parse, dispatch, exit status
source/cli/output.loup       # exact byte output (UTF-8 check, putchar)
source/commands/head.loup    # line and byte selection, headers, errors
tests/*_test.loup            # unit tests (make test)
tests/fixtures/              # files read by the unit tests
tests/e2e.sh                 # end-to-end tests of build/head (make e2e)
specs/head/                  # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
