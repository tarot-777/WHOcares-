#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target="${1:-$HOME/WHOcares!}"
source_path="$(realpath -m -- "$source_dir")"
target_path="$(realpath -m -- "$target")"

if [[ "$source_path" == "$target_path" ]]; then
  echo "[*] WHOcares! is already at $target_path"
else
  mkdir -p "$target_path"
  rsync -a \
    --exclude=.git \
    --exclude=.direnv \
    --exclude=result \
    --exclude='result-*' \
    "$source_path/" "$target_path/"
  echo "[*] copied WHOcares! to $target_path"
fi

cd "$target_path"
echo "[*] generated tree:"
find . -maxdepth 3 -path './.git' -prune -o -type f -print | sort

echo
echo "[*] next:"
echo "  nix flake check --no-build path:$target_path"
echo "  nh home build . -c malachi@coffin"
echo "  nh home switch . -c malachi@coffin"
