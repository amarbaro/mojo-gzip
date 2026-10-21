from gzip import GzFile, read_all, compress, decompress, crc32

def main() raises:
    var g = GzFile(".work/fx/text.gz")                 # streams: memory stays flat
    var buf = List[UInt8](length=1 << 17, fill=0)
    var c = UInt32(0)
    while True:
        var n = g.read(buf)
        if n == 0:
            break
        c = crc32(Span(buf)[:n], c)
    g.close()                                    # raises if the file was truncated
    var z = compress("hello".as_bytes(), 9, "zlib")
    print(len(decompress(z)), c)
