# One operation per run, printing what tools/oracle.py prints for the same arguments:
#   read IN | decompress IN | crc IN | adler IN  -> "<len> <crc32>" or "error"
#   compress IN OUT LEVEL FORMAT | write IN OUT LEVEL -> writes OUT (the gate inflates it with Python)
from std.sys import argv
from gzip import GzFile, read_all, write_all, compress, decompress, crc32, adler32


def raw(path: String) raises -> List[UInt8]:
    with open(path, "r") as f:
        return f.read_bytes()


def main() raises:
    var a = argv()
    var op = String(a[1])
    try:
        if op == "read" or op == "decompress":
            var d = read_all(String(a[2])) if op == "read" else decompress(raw(String(a[2])))
            print(len(d), crc32(d))
        elif op == "crc" or op == "adler":
            var d = raw(String(a[2]))
            var c = crc32(Span(d)[: len(d) // 2])
            print(len(d), crc32(Span(d)[len(d) // 2 :], c) if op == "crc" else adler32(d))
        elif op == "compress":
            var c = compress(raw(String(a[2])), Int(a[4]), String(a[5]))
            with open(String(a[3]), "w") as f:
                f.write_bytes(c)
            print("ok")
        else:
            write_all(String(a[3]), raw(String(a[2])), Int(a[4]))
            print("ok")
    except e:
        print("error")
