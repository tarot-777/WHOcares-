#!/usr/bin/env bash
set -euo pipefail

# Run from ~/Documents if your tree currently looks like:
#   ./aegis-dualis-fixed/{flake.nix,settings.nix,...}
#   ./home ./hosts ./lib ./shells
#
# It creates ~/WHOcares! as the real flake root.

src="${1:-$PWD}"
dst="${2:-$HOME/WHOcares!}"

mkdir -p "$dst"
rsync -a "$src/aegis-dualis-fixed/" "$dst"/
for d in home hosts lib shells; do
  if [[ -d "$src/$d" ]]; then
    rsync -a "$src/$d/" "$dst/$d"/
  fi
done

cd "$dst"
echo "[*] repaired flake root at $dst"
echo "[*] run:"
echo "    nix flake check --no-build"
echo "    nh home switch . -c malachi@coffin"
