#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine_path="${GODOT_BIN:-/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
# Keep test save files isolated from a player's real journey.
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT
export XDG_DATA_HOME="$test_dir/data"
export XDG_CONFIG_HOME="$test_dir/config"
export XDG_CACHE_HOME="$test_dir/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
"$engine_path" --version | grep -q '^4\.7\.2\.stable'
"$engine_path" --headless --path "$project_dir" --script res://tests/smoke.gd -- --smoke
