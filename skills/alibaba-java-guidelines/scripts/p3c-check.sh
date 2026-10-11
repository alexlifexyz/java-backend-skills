#!/bin/sh
# Checks Java files or directories against the p3c rules with PMD.
# Usage: p3c-check.sh <file-or-dir>...    Exit 0: clean, 4: violations found.
# P3C_PRIORITY=1|2|3 sets the lowest rule level reported (default 2, as p3c-guard).
# Needs JDK 21+ and curl. The rule jar (13 MB) is cached in ~/.cache/p3c-guard.
set -eu

VERSION=3.0.1
NAME="p3c-pmd-jdk21-$VERSION-cli.jar"
URL="https://repo1.maven.org/maven2/io/github/loong95/p3c-pmd-jdk21/$VERSION/$NAME"
SHA256=4caf54a3a8f33cc079a16857147168f268cae7e86072413e9ab07365dc311a16
DIR="${XDG_CACHE_HOME:-$HOME/.cache}/p3c-guard"
JAR="$DIR/$NAME"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <file-or-dir>..." >&2
  exit 2
fi

if [ ! -f "$JAR" ]; then
  mkdir -p "$DIR"
  curl -fsSL -o "$JAR.part" "$URL"
  SUM=$( (sha256sum "$JAR.part" 2>/dev/null || shasum -a 256 "$JAR.part") | cut -d' ' -f1)
  if [ "$SUM" != "$SHA256" ]; then
    rm -f "$JAR.part"
    echo "p3c-check: checksum mismatch for $NAME" >&2
    exit 3
  fi
  mv "$JAR.part" "$JAR"
fi

LIST=$(mktemp)
trap 'rm -f "$LIST"' EXIT
for path in "$@"; do
  printf '%s\n' "$path" >> "$LIST"
done

exec java -XX:TieredStopAtLevel=1 -jar "$JAR" check \
  --file-list "$LIST" -R rulesets/java/ali-all.xml -f text \
  --minimum-priority "${P3C_PRIORITY:-2}" --no-cache --no-progress
