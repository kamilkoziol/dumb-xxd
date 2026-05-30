# dumb-xxd

A simple hex dump tool written in Zig 0.16, similar to `xxd`. Reads binary input and prints a formatted hex dump with offset, hex pairs, and ASCII representation.

## Output format

```
00000000: 6865 6c6c  6f20 776f  726c 640a       hello.
00000010: 6465 6164 beef                         dead.
```

Each line shows:
- Byte offset (hex)
- Hex pairs grouped by 2 bytes
- ASCII representation (non-printable bytes shown as `.`)

## Usage

```sh
# From stdin
echo "hello world" | dumb_xxd

# From file
dumb_xxd input.bin

# Output to file
dumb_xxd input.bin -o out.txt

# Both
dumb_xxd input.bin -o out.txt
```

## Build

Requires Zig `0.16.0`.

```sh
zig build          # builds to zig-out/bin/dumb_xxd
zig build run      # build and run
zig build test     # run tests
```

## Project structure

```
src/
  main.zig   # CLI: arg parsing, reader/writer setup
  root.zig   # library module (dumb_xxd)
```

The core logic lives in `root.zig` and is exposed as a reusable `dumb_xxd` module. The CLI in `main.zig` wires up input (stdin or file) and output (stdout or file) using Zig 0.16's `std.Io` buffered reader/writer API.

## Notes on Zig 0.16 IO

This project uses Zig 0.16's new `std.Io` system instead of the legacy `std.io`:

- `Io.File.Writer` / `Io.File.Reader` are concrete buffered types — use them directly, do not copy `.interface` into a separate variable (the interface holds a self-referential pointer that becomes stale after a copy)
- `reader.readSliceShort(buf)` reads up to `buf.len` bytes without blocking for a full buffer — equivalent to POSIX `read()`
- `reader.take(n)` blocks until exactly `n` bytes are available
- Files are opened via `std.Io.Dir.cwd().openFile(io, path, ...)` / `createFile(...)`
