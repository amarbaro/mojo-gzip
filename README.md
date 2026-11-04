# mojo-gzip

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-gzip/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-gzip/actions/workflows/ci.yml) [![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-gzip)](https://github.com/amarbaro/mojo-gzip/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-gzip)](https://github.com/amarbaro/mojo-gzip/blob/main/LICENSE)
<!-- /badges -->

<!-- install -->
Install: `pixi add mojo-gzip` once published. For now: `git clone https://github.com/amarbaro/mojo-gzip`, then `mojo run -I mojo-gzip/src app.mojo`.

```mojo
from std.os import remove
from gzip import GzFile, compress, crc32


def main() raises:
    var data = List[UInt8](length=1 << 20, fill=65)  # 1 MiB of "A"
    var f = open("quickstart.gz", "w")
    f.write_bytes(compress(data, 6, "gzip"))
    var g = GzFile("quickstart.gz")  # streams: memory stays flat
    var buf = List[UInt8](length=1 << 17, fill=0)
    var c = UInt32(0)
    var n = g.read(buf)
    while n > 0:
        c = crc32(Span(buf)[:n], c)
        n = g.read(buf)
    g.close()  # raises if the file was truncated
    remove("quickstart.gz")
    print("crc matches:", c == crc32(data))
```
<!-- /install -->

Read and write gzip, zlib and raw deflate from Mojo, plus crc32 and adler32. It calls the
system `libz.so.1`, loaded at run time, so `mojo run` and `mojo build` need no linker flag.
159 lines. Every result is checked against Python `gzip`/`zlib` on 20 fixtures, including
truncated, bit-flipped and multi-member files.

Requires Mojo 1.2 on Linux and `libz.so.1` (present on every desktop and server distro;
no `-dev` package needed). Builds on Mojo 1.2 nightly too.

## What you get

- `GzFile(path, mode="rb")`: streaming `.gz` file. `read(buf)` fills a buffer you own and
  returns the byte count (0 at end); `write(span)`; `close()`. Modes `rb`, `wb`, `ab`, with
  a level digit (`wb9`). Plain files read through unchanged; members are joined.
- `read_all(path)`, `write_all(path, data, level=6)`.
- `compress(data, level=6, format="gzip")` and `decompress(data, format="auto")`, in memory.
  Formats `gzip`, `zlib`, `raw`; `auto` tells gzip from zlib. `decompress` joins gzip
  members and raises on truncated, corrupt or trailing data.
- `crc32(data, start=0)`, `adler32(data, start=1)`: equal to Python `zlib.crc32`/`adler32`, chainable.
- Errors are `gzip: <path>: <zlib message>`.

API: [docs/api.md](docs/api.md). Design: [docs/design.md](docs/design.md).

## Performance

`scripts/bench.sh` (`tests/bench.mojo` vs `tools/bench_oracle.py`): 21.8 MB inflated in 15 to 17 ms
against Python 19 to 20 ms, deflate 3 ms on both; same libz underneath. Streaming 50 MB of output through `GzFile` peaks at 12 MB (gated below 30 MB).

## Checks

| Script | What |
|---|---|
| `scripts/check.sh` | 43 read/decompress/crc/adler results identical to `tools/oracle.py`; 60 files written by the library (5 inputs, levels 1/6/9, 3 formats, plus `GzFile` writes) inflate under Python to the source; streaming RSS; API errors |
| `scripts/selfcheck.sh` | 4 mutants (dropped member, truncation missed, crc chain, header swap) all rejected |
| `scripts/bench.sh` | the speed numbers above, 3 runs each, peak RSS |
| `scripts/ci.sh` | install and gate, same on GitHub and a local VM |

## License

Apache-2.0.
