#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine_path="${GODOT_BIN:-/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.runtime/data}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.runtime/config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.runtime/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
exec "$engine_path" --path "$project_dir" "$@"
