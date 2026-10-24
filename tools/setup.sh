#!/usr/bin/env bash
set -euo pipefail
# Linux x86_64 cloud bootstrap; does not change tracked project files.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine_dir="${GODOT_INSTALL_DIR:-/workspace/tools/godot-4.7.2}"
engine_path="$engine_dir/Godot_v4.7.2-stable_linux.x86_64"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.runtime/cache}"
mkdir -p "$engine_dir" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
if [[ ! -x "$engine_path" ]]; then
  download_dir="$(mktemp -d)"
  trap 'rm -rf -- "$download_dir"' EXIT
  curl --fail --location --retry 2 --output "$download_dir/engine.zip" \
    https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
  python3 - "$download_dir/engine.zip" "$engine_dir" <<'PYVERIFY'
import hashlib, pathlib, sys, zipfile
archive = pathlib.Path(sys.argv[1])
expected = "9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65"
if hashlib.sha512(archive.read_bytes()).hexdigest() != expected:
    raise SystemExit("Godot SHA-512 verification failed")
with zipfile.ZipFile(archive) as bundle:
    bundle.extract("Godot_v4.7.2-stable_linux.x86_64", sys.argv[2])
(pathlib.Path(sys.argv[2]) / "Godot_v4.7.2-stable_linux.x86_64").chmod(0o755)
PYVERIFY
fi
"$engine_path" --version | grep -q '^4\.7\.2\.stable'
"$engine_path" --headless --path "$project_dir" --editor --import --quit
printf 'Godot ready: %s\n' "$engine_path"
