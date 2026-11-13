#!/usr/bin/env bash
set -euo pipefail
id=com.github.andresdev5.kickoffgroups
src="$(cd "$(dirname "$0")" && pwd)/package"
dest="$HOME/.local/share/plasma/plasmoids/$id"
rm -rf "$dest"
mkdir -p "$(dirname "$dest")"
cp -r "$src" "$dest"
echo "Instalado en $dest"
