# Errors are raised, not printed: a truncated .gz fails at close(), a missing file at open.
from gzip import GzFile, read_all, compress, decompress


def main() raises:
    var ok = False
    try:
        _ = read_all(".work/fx/trunc.gz")
    except e:
        ok = String(e).startswith("gzip: ")
    if not ok:
        raise Error("api: truncated .gz did not raise gzip: ...")
    ok = False
    try:
        _ = GzFile(".work/no/such.gz")
    except e:
        ok = True
    if not ok:
        raise Error("api: missing file did not raise")
    var s = "abc" * 1000
    var back = decompress(compress(s.as_bytes(), 9, "raw"), "raw")
    if String(unsafe_from_utf8=back) != s:
        raise Error("api: raw round trip differs")
    print("api: ok")
