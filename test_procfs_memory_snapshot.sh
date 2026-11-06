#!/usr/bin/env bash
#
# Tests for procfs-memory-snapshot.
#
# Run with: bash test_procfs_memory_snapshot.sh
#
# These tests exercise the real /proc filesystem.  They are deterministic
# because the fields we read (MemTotal, VmRSS) are stable for a running
# process and for the kernel's own reporting.  We never sleep, never
# compare wall-clock time, and never assume a specific memory size.

set -euo pipefail

# Source the library under test.
# shellcheck source=procfs_memory_snapshot.sh
source "$(dirname "$0")/procfs_memory_snapshot.sh"

pass=0
fail=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="$3"
    if [[ "$expected" == "$actual" ]]; then
        printf 'ok - %s\n' "$label"
        pass=$((pass + 1))
    else
        printf 'not ok - %s\n' "$label"
        printf '  expected: %q\n' "$expected"
        printf '  actual:   %q\n' "$actual"
        fail=$((fail + 1))
    fi
}

assert_success() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok - %s\n' "$label"
        pass=$((pass + 1))
    else
        printf 'not ok - %s\n' "$label"
        fail=$((fail + 1))
    fi
}

assert_failure() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'not ok - %s\n' "$label"
        fail=$((fail + 1))
    else
        printf 'ok - %s\n' "$label"
        pass=$((pass + 1))
    fi
}

# --- meminfo_field -------------------------------------------------------

# MemTotal is always present on Linux and is a positive integer in kB.
memtotal=$(meminfo_field MemTotal)
assert_success "meminfo_field MemTotal succeeds" meminfo_field MemTotal
if [[ "$memtotal" =~ ^[0-9]+$ ]] && (( memtotal > 0 )); then
    printf 'ok - MemTotal is a positive integer\n'
    pass=$((pass + 1))
else
    printf 'not ok - MemTotal is a positive integer (got %q)\n' "$memtotal"
    fail=$((fail + 1))
fi

# The colon-suffixed form must return the same value.
memtotal_colon=$(meminfo_field "MemTotal:")
assert_eq "$memtotal" "$memtotal_colon" "meminfo_field accepts trailing colon"

# MemFree is also always present.
memfree=$(meminfo_field MemFree)
assert_success "meminfo_field MemFree succeeds" meminfo_field MemFree
if [[ "$memfree" =~ ^[0-9]+$ ]] && (( memfree > 0 )); then
    printf 'ok - MemFree is a positive integer\n'
    pass=$((pass + 1))
else
    printf 'not ok - MemFree is a positive integer (got %q)\n' "$memfree"
    fail=$((fail + 1))
fi

# A field that does not exist must fail, not print an empty line.
assert_failure "meminfo_field rejects unknown field" meminfo_field NoSuchFieldXYZ

# An empty field name must fail with a usage error.
assert_failure "meminfo_field rejects empty name" meminfo_field ""

# --- process_rss ---------------------------------------------------------

# Our own shell's PID is guaranteed to exist while this test runs.
self_rss=$(process_rss $$)
assert_success "process_rss on self succeeds" process_rss $$
if [[ "$self_rss" =~ ^[0-9]+$ ]] && (( self_rss > 0 )); then
    printf 'ok - self RSS is a positive integer\n'
    pass=$((pass + 1))
else
    printf 'not ok - self RSS is a positive integer (got %q)\n' "$self_rss"
    fail=$((fail + 1))
fi

# PID 1 (init) always exists on Linux containers too.
init_rss=$(process_rss 1)
assert_success "process_rss on PID 1 succeeds" process_rss 1
if [[ "$init_rss" =~ ^[0-9]+$ ]] && (( init_rss > 0 )); then
    printf 'ok - PID 1 RSS is a positive integer\n'
    pass=$((pass + 1))
else
    printf 'not ok - PID 1 RSS is a positive integer (got %q)\n' "$init_rss"
    fail=$((fail + 1))
fi

# A PID that cannot exist (max PID + 1) must fail cleanly.
assert_failure "process_rss rejects nonexistent pid" process_rss 99999999

# Non-numeric PID must be rejected with a usage error.
assert_failure "process_rss rejects non-numeric pid" process_rss not_a_pid

# Empty PID must be rejected.
assert_failure "process_rss rejects empty pid" process_rss ""

# --- summary -------------------------------------------------------------

printf '\n# %d passed, %d failed\n' "$pass" "$fail"
if (( fail > 0 )); then
    exit 1
fi
exit 0
