#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte) and exit status with the expected ones.
#
# usage: tests/e2e.sh BINARY
#
# The cases run in a temporary directory holding the fixture files made
# below, so error messages show short names.

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDERR [ARGS...]
# Runs BINARY ARGS... and compares standard error and the exit status.
check_err() {
    local name=$1 want_status=$2 want_err=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        echo "    want stderr: $want_err"
        sed 's/^/    got stderr:  /' "$TMP/err" | head -5
    fi
}

cd "$TMP" || exit 1
seq 1 12 > twelve
printf 'a\nb\nc' > abc
printf 'h\303\251llo\n' > utf
printf 'x\0y\0z' > nul
printf '\001\002\377\376\375\n' > binary
: > empty
mkdir dir

# Lines
check "default ten lines"  0 $'1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n' twelve
check "-n 3"               0 $'1\n2\n3\n'                       -n 3 twelve
check "-n3 attached"       0 $'1\n2\n3\n'                       -n3 twelve
check "--lines=2"          0 $'1\n2\n'                          --lines=2 twelve
check "--li 2 abbrev."     0 $'1\n2\n'                          --li 2 twelve
check "-n -10"             0 $'1\n2\n'                          -n -10 twelve
check "-n -0 is all"       0 $'a\nb\nc'                         -n -0 abc
check "-n 0"               0 ''                                 -n 0 twelve
check "more than there are" 0 $'a\nb\nc'                        -n 50 abc
check "partial last line"  0 $'a\nb\n'                          -n -1 abc
check "empty file"         0 ''                                 empty
IN=abc check "stdin"       0 $'a\n'                             -n 1
IN=abc check "dash"        0 $'a\n'                             -n 1 -
check "-5 obsolete"        0 $'1\n2\n3\n4\n5\n'                 -5 twelve
check "+2 and suffix"      0 $'1\n2\n'                          -n +2 twelve
printf 'x\0y\0' > "$TMP/want-z"
check_file "-z"            0 "$TMP/want-z"                      -z -n 2 nul

# Bytes
check "-c 5"               0 $'1\n2\n3'                         -c 5 twelve
check "-c -22"             0 $'1\n2\n3'                         -c -22 twelve
check "-5c obsolete"       0 $'1\n2\n3'                         -5c twelve
check "-c 2 in a char"     0 $'h\303'                           -c 2 utf
check "-c 3 whole char"    0 $'h\303\251'                       -c 3 utf
check "-c -5 in a char"    0 $'h\303'                           -c -5 utf
check "-c 1k"              0 "$(cat twelve)"$'\n'               -c 1k twelve
printf '\001\002\377' > "$TMP/want-bin"
check_file "binary -c 3"   0 "$TMP/want-bin"                    -c 3 binary
if [ "$("$BIN" -c 3 binary | od -An -tx1)" = " 01 02 ff" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: binary -c 3 into a pipe"
fi
{ echo pre; "$BIN" -c 2 utf; echo post; } > "$TMP/compound"
if [ "$(od -An -c "$TMP/compound" | tr -s ' ')" = " p r e \n h 303 p o s t \n" ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: raw bytes between other writers"
fi

# Headers
check "two files"          0 $'==> abc <==\na\n\n==> twelve <==\n1\n'  -n 1 abc twelve
check "-q"                 0 $'a\n1\n'                          -q -n 1 abc twelve
check "-v one file"        0 $'==> abc <==\na\n'                -v -n 1 abc
IN=abc check "stdin header" 0 $'==> standard input <==\na\n'    -vn1
check "-q then -v"         0 $'==> abc <==\na\n'                -qv -n1 abc

# Errors
check "missing file"       1 $'==> abc <==\na\n\n==> twelve <==\n1\n'  -n 1 abc missing twelve
check_err "missing message" 1 "head: cannot open 'missing' for reading: No such file or directory" missing
check "directory"          1 $'==> dir <==\n\n==> abc <==\na\n'  -n 1 dir abc
check_err "directory message" 1 "head: error reading 'dir': Is a directory" dir
check_err "bad count"      1 "head: invalid number of lines: 'x'"        -n x twelve
check_err "bad bytes"      1 "head: invalid number of bytes: '1kx'"      -c 1kx twelve
check_err "too large"      1 "head: invalid number of bytes: '1Z': Value too large for defined data type" -c 1Z twelve
check_err "missing argument" 1 $'head: option requires an argument -- \'n\'\nTry \'head --help\' for more information.' -n
check_err "long argument"  1 $'head: option \'--lines\' requires an argument\nTry \'head --help\' for more information.' --lines
check_err "invalid option" 1 $'head: invalid option -- \'x\'\nTry \'head --help\' for more information.' -x
check_err "trailing option" 1 $'head: invalid trailing option -- x\nTry \'head --help\' for more information.' -3x
check_err "ambiguous"      1 $'head: option \'--v\' is ambiguous; possibilities: \'--verbose\' \'--version\'\nTry \'head --help\' for more information.' --v

# Help and version
check "version"            0 $'head (loup-cmd-head) 0.1.0\n'    --version
"$BIN" --help > "$TMP/help"
if head -1 "$TMP/help" | grep -q '^Usage: head \[OPTION\]... \[FILE\]...$'; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: help"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
