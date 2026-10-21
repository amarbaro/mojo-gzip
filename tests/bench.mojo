# Inflate argv[1] (a .gz) fully 20 times, then gzip-compress the result once at level 6.
# Prints the bytes and ms of each part. Same work as tools/bench_oracle.py.
from std.sys import argv
from std.time import perf_counter_ns
from gzip import read_all, compress


def main() raises:
    var t = perf_counter_ns()
    var n = 0
    var d = List[UInt8]()
    for _ in range(20):
        d = read_all(String(argv()[1]))
        n += len(d)
    var t1 = perf_counter_ns()
    var c = compress(d, 6)
    var t2 = perf_counter_ns()
    print("inflate", n, "B", (t1 - t) // 1_000_000, "ms; deflate", len(c), "B", (t2 - t1) // 1_000_000, "ms")
