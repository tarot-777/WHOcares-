#!/usr/bin/env bash
set -euo pipefail

target="${1:-$HOME/WHOcares!}"

mkdir -p "$target"
rsync -a --delete ./ "$target"/

cd "$target"
echo "[*] generated tree:"
find . -maxdepth 3 -type f | sort

echo
echo "[*] next:"
echo "  nix flake check --no-build"
echo "  nh home build . -c malachi@coffin"
echo "  nh home switch . -c malachi@coffin"
