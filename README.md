Simple tool to deduplicate files in a directory.

The dedup.rb tool uses the `sha256sum` command line tool to identify duplicate files.  It then replaces
the duplicates with hard links.

Limitations:
- Does not support running across multiple devices.
- Do not run as root.
- Stores all data in memory, so can require a lot of RAM.  No incremental runs.
- I would not try it on Windows without a lot of testing.
