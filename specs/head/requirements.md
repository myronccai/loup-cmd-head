# Requirements: head

## Introduction

`head` prints the first part of each file: by default its first ten lines.
This repository recreates GNU coreutils `head` in Loup, including counts in
lines or bytes, the "all but the last N" form, file-name headers and GNU's
number syntax with multiplier suffixes. It is the third command in the
loup-cmd series.

## Requirements

### Requirement 1: Lines

**User Story:** As a shell user, I want the start of a file so that I can
look at it without paging through all of it.

#### Acceptance Criteria

1. WHEN head is run without a count, THE program SHALL print the first 10
   lines of each operand, or the whole operand if it has fewer.
2. WHEN `-n N` (`--lines=N`) is given, THE program SHALL print the first N
   lines; WHEN `-n -N` is given, THE program SHALL print all but the last N.
3. THE program SHALL count a final line without a newline as a line, and
   copy every byte of the lines it prints unchanged.
4. WHEN `-z` is given, THE program SHALL end lines with NUL instead of
   newline.

### Requirement 2: Bytes

**User Story:** As a shell user, I want an exact number of bytes so that I
can take a fixed-size prefix of any file, text or binary.

#### Acceptance Criteria

1. WHEN `-c N` (`--bytes=N`) is given, THE program SHALL print the first N
   bytes; WHEN `-c -N` is given, THE program SHALL print all but the last N.
2. THE program SHALL print exactly those bytes, even when N falls inside a
   multi-byte character or the input is not text.

### Requirement 3: Numbers

**User Story:** As a script author, I want GNU's number syntax so that
existing scripts behave the same.

#### Acceptance Criteria

1. THE program SHALL accept a count with optional leading blanks and `+`,
   and the multiplier suffixes `b` (512), `K`/`k`/`KiB` (1024), `kB` (1000),
   and likewise `M`, `G`, `T`, `P`, `E` (and `MB`, `MiB`, ...).
2. WHEN a count is not a number, THE program SHALL print
   `head: invalid number of lines: 'X'` (or `bytes`) and exit with status 1;
   WHEN it does not fit, SHALL add `: Value too large for defined data type`.
3. WHEN the first argument is `-N` optionally followed by `c`, `l`, `b`, `k`,
   `m`, `q`, `v` or `z`, THE program SHALL treat it as GNU's obsolete count
   option (`-5` is `-n 5`, `-5c` is `-c 5`).

### Requirement 4: Headers

**User Story:** As a shell user, I want to know which file each part came
from when I look at several at once.

#### Acceptance Criteria

1. WHEN more than one operand is given, THE program SHALL print
   `==> NAME <==` before each one, with an empty line before every header
   but the first; standard input is named `standard input`.
2. WHEN `-q` (`--quiet`, `--silent`) is given, THE program SHALL print no
   headers; WHEN `-v` (`--verbose`) is given, SHALL print them even for one
   operand. The last of the two wins.

### Requirement 5: Command line and errors

**User Story:** As a shell user, I want GNU's option syntax and messages so
that head fits into existing scripts.

#### Acceptance Criteria

1. THE program SHALL accept combined short options (`-qn5`), options after
   operands, `--`, `-` for standard input, and long options abbreviated to a
   unique prefix; the last count option wins.
2. WHEN an option is unknown, ambiguous, lacks its argument or has one it
   does not take, THE program SHALL print GNU's message and
   `Try 'head --help' for more information.` and exit with status 1.
3. WHEN an operand does not exist, THE program SHALL print
   `head: cannot open 'NAME' for reading: No such file or directory`; WHEN it
   is a directory, SHALL print its header and
   `head: error reading 'NAME': Is a directory`; in both cases continue and
   exit with status 1.
4. WHEN `--help` or `--version` is given, THE program SHALL print the help
   text or the version line and exit with status 0.
