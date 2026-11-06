# procfs-memory-snapshot

A tiny shell library that reads `/proc/meminfo` and `/proc/<pid>/status` to report current memory usage and RSS for a process.

## Usage

Source the script, then call its functions:

```bash
source procfs_memory_snapshot.sh

# Total physical memory in kB (as reported by the kernel)
meminfo_field MemTotal
# => 16384000

# Resident set size of the current shell in kB
process_rss $$
# => 3420
```

Both functions print a single integer to stdout and exit non-zero on error. `meminfo_field` accepts the field name with or without a trailing colon.

## Why this exists

Reading procfs from shell scripts usually means a `grep | awk` pipeline scattered through the script. That works, but it silently returns an empty string when a field is missing, and the caller has to remember the exact spelling and the `kB` suffix. This library centralises the parsing and makes missing fields a hard error, so a typo fails loudly rather than producing a zero.

The trade-off: the functions read the real `/proc` paths with no injection point. That makes them trivial to use but impossible to unit-test against a fake procfs. The test suite therefore runs against the real procfs, which is deterministic for `MemTotal`, `MemFree`, and `VmRSS` on any Linux host.

## The awkward edge

`process_rss` reads `VmRSS` from `/proc/<pid>/status`, not from `/proc/<pid>/statm`. `statm` reports pages, not kB, so mixing the two would give inconsistent units with `meminfo_field`. If you need page counts, read `statm` yourself; this library deliberately stays in kB.
