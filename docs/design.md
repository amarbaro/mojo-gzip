# Design

Rules: the system libz does the compression; this library only moves bytes, and streaming keeps
memory flat whatever the file size.

## libz loaded at run time

`external_call` binds at link time, and `mojo run` (JIT) cannot resolve libz symbols
("Symbols not found: crc32"). `OwnedDLHandle("libz.so.1")` works for both `mojo run` and
`mojo build` and needs no `-dev` package (only the runtime soname). A `dlsym` costs about 42 ns
(measured in mojo-sqlite); every call here moves at least a buffer, so caching addresses would
save nothing measurable.

## Streaming

`GzFile.read(buf)` fills a buffer the caller owns and reuses: inflating 50 MB through 128 KiB
peaks at 12 MB RSS (gated below 30 MB). `gzbuffer` is set to 128 KiB so zlib's own reads match.

## Errors zlib reports late

zlib sets `Z_BUF_ERROR` (unexpected end of file) on the `gzread` call that returns a truncated
stream's last bytes and clears it on the next call, which then returns 0 as if the file ended
cleanly. `GzFile` latches the error and raises on the next `read` and on `close`, so a truncated
file can never pass as complete. The gate's `trunc.gz` and a mutant pin this.

## In memory

`compress` sizes its output with `deflateBound` and makes one `deflate(Z_FINISH)` call.
`decompress` doubles its output buffer until done, resets the stream for each further gzip
member, and names its failures: truncated input, corrupt input, trailing data. `z_stream` is a
112-byte block whose fields are written at their x86-64/aarch64 offsets.

## Speed

Both sides run the same libz, so speed equals Python's: `scripts/bench.sh` inflates 21.8 MB in
15 to 17 ms (Python 19 to 20 ms) and deflates in 3 ms on both.
