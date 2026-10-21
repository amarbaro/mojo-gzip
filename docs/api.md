# API

`from gzip import ...`

| Name | What |
|---|---|
| `GzFile(path, mode="rb") raises` | gzopen. Modes `rb`, `wb`, `ab`, optional level digit `wb1`..`wb9`. Raises `gzip: cannot open <path>` |
| `GzFile.read(mut buf: List[UInt8]) raises -> Int` | inflates into `buf[0:len(buf)]`, returns bytes read, 0 at end. Raises on corrupt or truncated data (on the call after the last good bytes) |
| `GzFile.write(data: Span[UInt8]) raises` | deflates `data` |
| `GzFile.close() raises` | flushes; raises `unexpected end of file` for a truncated read. Also closed (silently) on destruction |
| `read_all(path) raises -> List[UInt8]` | whole inflated content |
| `write_all(path, data, level=6) raises` | one gzip file |
| `compress(data, level=6, format="gzip") raises -> List[UInt8]` | `format`: `gzip`, `zlib`, `raw` |
| `decompress(data, format="auto") raises -> List[UInt8]` | `auto` = gzip or zlib by header. Raises `gzip: truncated input`, `corrupt input`, `trailing data` |
| `crc32(data, start: UInt32 = 0) -> UInt32` | CRC-32 (gzip, zip, PNG) |
| `adler32(data, start: UInt32 = 1) -> UInt32` | Adler-32 (zlib) |

Notes:

- `GzFile` follows gzread: bytes after the last gzip member are ignored, as `zcat` does.
  `decompress` is strict and raises `trailing data`.
- One call handles at most 4 GiB of input (zlib's `uInt` counters); stream bigger data with `GzFile`.
- Output bytes of `compress` are whatever the system libz produces; they decode everywhere but
  may differ byte for byte from another zlib build (zlib-ng, Python's bundled copy).
