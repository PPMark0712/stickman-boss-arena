#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ -n "${GODOT:-}" ]]; then
	GODOT_BIN="$GODOT"
elif command -v godot >/dev/null 2>&1; then
	GODOT_BIN="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
	GODOT_BIN="$(command -v godot4)"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
	GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "找不到 Godot 4.7.2。请安装 Godot，或设置 GODOT=/path/to/Godot。" >&2
	exit 1
fi

if [[ ! -f ".tools/templates/web_nothreads_release.zip" ]]; then
	echo "缺少 Godot Web 导出模板，正在下载……"
	GODOT="$GODOT_BIN" python3 tools/fetch_templates.py
fi

echo "运行测试并导出 Web……"
GODOT="$GODOT_BIN" python3 tools/build.py all

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8060}"
echo "游戏地址：http://${HOST}:${PORT}"
echo "按 Ctrl-C 停止本地服务。"
exec python3 -m http.server "$PORT" --bind "$HOST" --directory build/web
