#!/usr/bin/env bash
# Proves the gate rejects wrong code: each mutant is applied to a copy of the tree and
# scripts/check.sh must FAIL on it. Then the oracle as its own stand-in must pass the oracle part.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
mutants=(
  "src/gzip/gz.mojo|            _ = z.call[\"inflateReset\", Int32](s.unsafe_ptr())  # next gzip member|            err = \"x\"; break|second gzip member dropped"
  "src/gzip/gz.mojo|            self.bad = True|            pass|truncated stream read as complete"
  "src/gzip/gz.mojo|(UInt(start), data.unsafe_ptr()|(UInt(0), data.unsafe_ptr()|crc32 chaining ignored"
  "src/gzip/gz.mojo|31 if format == \"gzip\" else (15|15 if format == \"gzip\" else (31|gzip and zlib headers swapped"
)
for m in "${mutants[@]}"; do
  IFS='|' read -r file from to why <<< "$m"
  d=$ROOT/.work/mutant; rm -rf "$d"; mkdir -p "$d"
  cp -r src tests tools scripts examples "$d"; ln -s "$ROOT/.venv" "$d/.venv"; mkdir -p "$d/.work"; ln -s "$ROOT/.work/fx" "$d/.work/fx"
  python3 -I -c 'import sys; p,a,b=sys.argv[1:]; s=open(p).read(); assert a in s, "mutant does not apply: "+a; open(p,"w").write(s.replace(a,b,1))' "$d/$file" "$from" "$to" \
    || { echo "FAIL selfcheck: mutant does not apply ($why)"; exit 1; }
  if "$d/scripts/check.sh" > "$d.log" 2>&1; then echo "FAIL selfcheck: gate passed a mutant ($why)"; exit 1; fi
  echo "selfcheck: rejected ($why): $(grep -m1 FAIL "$d.log")"
done
CASES="python3 -I tools/oracle.py" scripts/check.sh > .work/oracle-self.log 2>&1 || { echo "FAIL selfcheck: oracle fails its own gate"; tail -3 .work/oracle-self.log; exit 1; }
echo "PASS selfcheck"
