#!/usr/bin/env bash
# The gate. Fixtures from tools/fixtures_oracle.py; every read/decompress/crc/adler result of
# $CASES (default: tests/cases.mojo built to .work/cases) must equal tools/oracle.py's, and every
# file it writes (compress, write) must inflate under Python to the source's length and crc32.
# Then streaming peak RSS and the API test. CASES="python3 -I tools/oracle.py" proves the gate.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work
M=.venv/bin/mojo
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
  rss=$(python3 -I -c 'import resource, subprocess, sys
subprocess.run(sys.argv[1:-1], stdout=open(sys.argv[-1], "w"), check=True)
print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)' .work/stream $F/zeros.gz .work/stream.out) || { echo "FAIL stream: .work/stream crashed"; exit 1; }
  [[ $(cat .work/stream.out) == "$($O crc $F/zeros)" ]] || { echo "FAIL stream: $(cat .work/stream.out)"; exit 1; }
  (( rss < 30000 )) || { echo "FAIL stream: peak RSS ${rss} KB for 50 MB inflated, want < 30000"; exit 1; }
  echo "stream: 50 MB inflated chunk by chunk, peak RSS ${rss} KB"
  $M run -I src tests/api.mojo || { echo "FAIL api: tests/api.mojo"; exit 1; }
  $M run -I src examples/quickstart.mojo > /dev/null || { echo "FAIL example: examples/quickstart.mojo"; exit 1; }
fi
echo "PASS all"
