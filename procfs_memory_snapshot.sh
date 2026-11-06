#!/usr/bin/env bash
#
# procfs-memory-snapshot
#
# Reads /proc/meminfo and /proc/<pid>/status to report current memory usage
# and RSS for a process.
#
# The library is designed to be sourced. It exposes two functions:
#
#   meminfo_field FIELD
#       Prints the numeric value (in kB, as reported by the kernel) for the
#       given field in /proc/meminfo.  Accepts names with or without a
#       trailing colon.  Exits non-zero if the field is missing.
#
#   process_rss PID
#       Prints the VmRSS value (in kB) for the given PID from
#       /proc/<pid>/status.  Exits non-zero if the process does not exist
#       or the file cannot be read.
#
# Both functions read from the real procfs paths.  There is no injection
# point for alternate roots because the brief asks for reading /proc/meminfo
# and /proc/<pid>/status, and a test double would be a different library.
# Tests exercise the real procfs, which is deterministic for these fields
# on any Linux host.

set -euo pipefail

# meminfo_field FIELD
#
# Extract a numeric field from /proc/meminfo.  The kernel prints lines like
#   MemTotal:       16384000 kB
# We strip the colon from the requested name so callers can pass either
# "MemTotal" or "MemTotal:".  The value is the second whitespace-separated
# token; we do not strip the "kB" suffix because callers may want to know
# the unit, but in practice every field we expose here is in kB.
meminfo_field() {
    local field="${1:-}"
    if [[ -z "$field" ]]; then
        echo "meminfo_field: missing field name" >&2
        return 2
    fi
    # Normalise: drop a single trailing colon if present.
    field="${field%:}"
    local line
    if ! line=$(grep -E "^${field}:" /proc/meminfo 2>/dev/null); then
        echo "meminfo_field: field '$field' not found in /proc/meminfo" >&2
        return 1
    fi
    # line looks like: "MemTotal:       16384000 kB"
    # shellcheck disable=SC2086
    set -- $line
    if [[ $# -lt 2 ]]; then
        echo "meminfo_field: malformed line for '$field'" >&2
        return 1
    fi
    printf '%s\n' "$2"
}

# process_rss PID
#
# Read VmRSS from /proc/<pid>/status.  Returns the value in kB as an
# integer.  We deliberately do not fall back to /proc/<pid>/statm because
# the brief names /proc/<pid>/status specifically, and statm reports pages
# rather than kB, which would make the units inconsistent with meminfo.
process_rss() {
    local pid="${1:-}"
    if [[ -z "$pid" ]]; then
        echo "process_rss: missing pid" >&2
        return 2
    fi
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        echo "process_rss: pid must be numeric, got '$pid'" >&2
        return 2
    fi
    local status="/proc/${pid}/status"
    if [[ ! -r "$status" ]]; then
        echo "process_rss: cannot read $status" >&2
        return 1
    fi
    local line
    if ! line=$(grep -E '^VmRSS:' "$status" 2>/dev/null); then
        echo "process_rss: VmRSS not found for pid $pid" >&2
        return 1
    fi
    # shellcheck disable=SC2086
    set -- $line
    if [[ $# -lt 2 ]]; then
        echo "process_rss: malformed VmRSS line for pid $pid" >&2
        return 1
    fi
    printf '%s\n' "$2"
}
