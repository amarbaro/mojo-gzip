"""Writes the gate's input files into DIR with Python gzip/zlib (deterministic: fixed seed, mtime 0)."""
import gzip, os, random, sys, zlib
d = sys.argv[1]; os.makedirs(d, exist_ok=True)
r = random.Random(7)
text = b"".join(b"line %d of the mojo-gzip fixture, some words repeat\n" % i for i in range(20000))
noise = r.randbytes(3 << 20)
def put(name, b): open(os.path.join(d, name), "wb").write(b)
def gz(b, lvl=6): return gzip.compress(b, lvl, mtime=0)
for name, b in {"empty": b"", "one": b"x", "text": text, "noise": noise, "zeros": bytes(50 << 20)}.items():
    put(name, b); put(name + ".gz", gz(b))
put("text.l1.gz", gz(text, 1)); put("text.l9.gz", gz(text, 9))
put("multi.gz", gz(text) + gz(b"second member\n") + gz(noise[:1000]))
put("trunc.gz", gz(text)[:-100])
put("trunc-trailer.gz", gz(text)[:-4])
g = bytearray(gz(text)); g[len(g) // 2] ^= 0x40; put("flip.gz", bytes(g))
g = bytearray(gz(text)); g[-5] ^= 1; put("badcrc.gz", bytes(g))
put("trailing.gz", gz(text) + b"garbage!")
put("text.zz", zlib.compress(text)); put("trunc.zz", zlib.compress(text)[:-50])
