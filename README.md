Simple tool to deduplicate files in a directory.

The dedup.rb tool uses the `sha256sum` command line tool to identify duplicate files.  It then replaces
the duplicates with hard links.

Limitations:
- Do not run across multiple file systems. Does not detect and will cause file loss.
- Stores all data in memory, so can require a lot of RAM.  Not persistent across runs.
- I would not try it on Windows without a lot of testing.
