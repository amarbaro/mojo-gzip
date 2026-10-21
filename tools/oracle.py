"""Oracle: the same operations as tests/cases.mojo with Python gzip/zlib."""
import gzip, sys, zlib
op, path = sys.argv[1], sys.argv[2]
W = {"gzip": 31, "zlib": 15, "raw": -15}
try:
    if op in ("read", "decompress"):
        raw = open(path, "rb").read()
        if op == "read" and raw[:2] != b"\x1f\x8b":
            d = raw  # gzopen passes plain files through
        elif op == "read":  # gzread: members joined, bytes after the last member ignored (zlib manual)
            d, rest = b"", raw
            while rest[:2] == b"\x1f\x8b":
                o = zlib.decompressobj(31)
                d += o.decompress(rest)
                if not o.eof:
                    raise EOFError
                rest = o.unused_data
        elif raw[:2] == b"\x1f\x8b":
            d = gzip.decompress(raw)
        else:
            o = zlib.decompressobj(15)
            d = o.decompress(raw)
            if not o.eof:
                raise EOFError
            if o.unused_data:
                raise ValueError
        print(len(d), zlib.crc32(d))
    elif op in ("crc", "adler"):
        d = open(path, "rb").read()
        print(len(d), zlib.crc32(d) if op == "crc" else zlib.adler32(d))
    elif op == "inflate":  # inflate PATH FORMAT: check what cases.mojo wrote
        d = zlib.decompress(open(path, "rb").read(), W[sys.argv[3]])
        print(len(d), zlib.crc32(d))
    elif op == "compress":
        o = zlib.compressobj(int(sys.argv[4]), zlib.DEFLATED, W[sys.argv[5]])
        open(sys.argv[3], "wb").write(o.compress(open(path, "rb").read()) + o.flush())
        print("ok")
    else:
        with gzip.open(sys.argv[3], "wb", int(sys.argv[4])) as f:
            f.write(open(path, "rb").read())
        print("ok")
except Exception:
    print("error")
