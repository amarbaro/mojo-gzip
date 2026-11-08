#!/usr/bin/env bash
# The gate. Fixtures from tools/fixtures_oracle.py; every read/decompress/crc/adler result of
# $CASES (default: tests/cases.mojo built to .work/cases) must equal tools/oracle.py's, and every
# file it writes (compress, write) must inflate under Python to the source's length and crc32.
# Then streaming peak RSS and the API test. CASES="python3 -I tools/oracle.py" proves the gate.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
M=${MOJO:-.venv/bin/mojo}
CASES=${CASES:-.work/cases}
if [[ $CASES == .work/cases ]]; then
  $M build -I src tests/cases.mojo -o .work/cases 2>.work/build.err || { echo "FAIL build: tests/cases.mojo"; cat .work/build.err; exit 1; }
fi
F=.work/fx; O="python3 -I tools/oracle.py"
[[ -f $F/multi.gz ]] || python3 -I tools/fixtures_oracle.py $F || { echo "FAIL setup: fixtures"; exit 1; }
n=0
one() {  # one OP FILE: impl and oracle must print the same line
  local got want; got=$($CASES "$1" "$F/$2") || true; want=$($O "$1" "$F/$2")
  [[ $got == "$want" ]] || { echo "FAIL oracle: $1 $2: got '$got' want '$want'"; exit 1; }
  n=$((n + 1))
}
for f in $(cd $F && ls); do
  case $f in *.gz) one read "$f"; one decompress "$f";; *.zz) one decompress "$f";; *) one read "$f"; one crc "$f"; one adler "$f";; esac
done
echo "oracle: $n read/decompress/crc/adler results identical, $(grep -c '' <(cd $F && ls)) fixtures"
w=0
for src in empty one text noise zeros; do
  want=$($O crc "$F/$src")
  for lvl in 1 6 9; do
    for fmt in gzip zlib raw; do
      $CASES compress "$F/$src" .work/out "$lvl" "$fmt" >/dev/null
      got=$($O inflate .work/out "$fmt"); [[ $got == "$want" ]] || { echo "FAIL roundtrip: compress $src $lvl $fmt: '$got' want '$want'"; exit 1; }
      w=$((w + 1))
    done
    $CASES write "$F/$src" .work/out "$lvl" >/dev/null
    got=$($O inflate .work/out gzip); [[ $got == "$want" ]] || { echo "FAIL roundtrip: write $src $lvl: '$got' want '$want'"; exit 1; }
    w=$((w + 1))
  done
done
echo "roundtrip: $w files written by impl inflate under Python to the source"
if [[ $CASES == .work/cases ]]; then
  $M build -I src tests/stream.mojo -o .work/stream 2>.work/build.err || { echo "FAIL build: tests/stream.mojo"; cat .work/build.err; exit 1; }
  maxrss() { python3 -I -c 'import resource, subprocess, sys
subprocess.run(sys.argv[1:-1], stdout=open(sys.argv[-1], "w"), check=True)
print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)' "$@"; }
  # peak RSS above an empty Mojo program: the floor is the toolchain's (11.6 MB on 1.2, 66.6 MB on the 1.3 nightly,
  # which loads libLLVM.so into every binary); the bar is the old 30000 KB absolute minus the 1.2 floor
  $M build -I src tests/empty.mojo -o .work/empty 2>.work/build.err || { echo "FAIL build: tests/empty.mojo"; cat .work/build.err; exit 1; }
  floor=$(maxrss .work/empty .work/empty.out) || { echo "FAIL stream: .work/empty crashed"; exit 1; }
  rss=$(maxrss .work/stream $F/zeros.gz .work/stream.out) || { echo "FAIL stream: .work/stream crashed"; exit 1; }
  rss=$((rss - floor))
  [[ $(cat .work/stream.out) == "$($O crc $F/zeros)" ]] || { echo "FAIL stream: $(cat .work/stream.out)"; exit 1; }
  (( rss < 18000 )) || { echo "FAIL stream: peak RSS ${rss} KB above an empty program for 50 MB inflated, want < 18000"; exit 1; }
  echo "stream: 50 MB inflated chunk by chunk, peak RSS ${rss} KB above an empty program"
  # built, not `mojo run`: on the 1.3 nightly the JIT process has the system libz loaded before ours (RTLD_DEEPBIND cannot
  # apply to an already-loaded library) and deflateInit2_ returns Z_STREAM_ERROR; see .work/nightly-fix/upstream-gzip.md
  $M build -I src tests/api.mojo -o .work/api 2>.work/build.err || { echo "FAIL build: tests/api.mojo"; cat .work/build.err; exit 1; }
  .work/api || { echo "FAIL api: tests/api.mojo"; exit 1; }
  $M build -I src examples/quickstart.mojo -o .work/quickstart 2>.work/build.err || { echo "FAIL build: examples/quickstart.mojo"; cat .work/build.err; exit 1; }
  .work/quickstart > /dev/null || { echo "FAIL example: examples/quickstart.mojo"; exit 1; }
fi
echo "PASS all"
