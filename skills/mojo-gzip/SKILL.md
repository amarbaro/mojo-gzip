---
name: mojo-gzip
description: "gzip/zlib/raw deflate and crc32/adler32 from Mojo via the system libz, no link flag. Use when Mojo code reads or writes .gz files, inflates a zlib stream, or needs a CRC-32."
---

# mojo-gzip

`mojo run -I <repo>/src app.mojo`.

    from gzip import GzFile, read_all, compress, decompress, crc32
    var data = read_all("x.gz")            # whole file
    var g = GzFile("x.gz")                 # or stream: g.read(buf) until 0, then g.close()

`close()` raises on a truncated file: always call it. Check: `scripts/check.sh` ends `PASS all`.
