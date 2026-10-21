"""Same work as tests/bench.mojo with Python gzip/zlib."""
import gzip, sys, time, zlib
t = time.perf_counter(); n = 0
for _ in range(20):
    d = gzip.open(sys.argv[1]).read(); n += len(d)
t1 = time.perf_counter()
o = zlib.compressobj(6, zlib.DEFLATED, 31); c = o.compress(d) + o.flush()
t2 = time.perf_counter()
print("inflate %d B %d ms; deflate %d B %d ms" % (n, (t1 - t) * 1000, len(c), (t2 - t1) * 1000))
