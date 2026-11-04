# 20,000 crc32 and adler32 calls on 64 bytes each: the per-call cost of the libz binding.
from std.time import perf_counter_ns
from gzip import crc32, adler32


def main() raises:
    var buf = List[UInt8](length=64, fill=7)
    var c = UInt32(0)
    var t = perf_counter_ns()
    for _ in range(20000):
        c = crc32(buf, c)
    var t1 = perf_counter_ns()
    var a = UInt32(1)
    for _ in range(20000):
        a = adler32(buf, a)
    var t2 = perf_counter_ns()
    print("crc32", c, (t1 - t) // 1000, "us;", "adler32", a, (t2 - t1) // 1000, "us (20000 x 64 B)")
