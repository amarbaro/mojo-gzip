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
