# Streams argv[1] through one 128 KiB buffer, chaining crc32: memory stays flat whatever the size.
from std.sys import argv
from gzip import GzFile, crc32


def main() raises:
    var g = GzFile(String(argv()[1]))
    var buf = List[UInt8](length=1 << 17, fill=0)
    var total = 0
    var c = UInt32(0)
    while True:
        var n = g.read(buf)
        if n == 0:
            break
        c = crc32(Span(buf)[:n], c)
        total += n
    g.close()
    print(total, c)
