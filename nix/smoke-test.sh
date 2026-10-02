#!/bin/sh
# Дымовой тест рантайма: Xvfb + software OpenGL + запуск собранной игры.
#
# Запуск (нужен собранный пакет в ./result):
#   nix build
#   nix shell nixpkgs#xvfb nixpkgs#mesa nixpkgs#mesa-demos \
#     --command sh nix/smoke-test.sh
#
# ВНИМАНИЕ: у Xvfb из nixpkgs нет расширения GLX, поэтому контекст OpenGL
# в headless-окружении не создаётся и игра падает. Скрипт всё равно полезен:
# он проверяет лончер, копирование ресурсов и инициализацию движка до GL.
set -u

RESULT="${1:-./result}"
export LIBGL_ALWAYS_SOFTWARE=1
export SHOOTER_DATA_DIR="${SHOOTER_DATA_DIR:-/tmp/shooter-smoke}"
rm -rf "$SHOOTER_DATA_DIR"

Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/tmp/shooter-xvfb.log 2>&1 &
XVFB_PID=$!
sleep 3
export DISPLAY=:99

echo "=== GLX available? ==="
glxinfo -B 2>&1 | head -5

echo "=== start game (30s timeout) ==="
timeout 30 "$RESULT/bin/shooter"
echo "exit=$?"

kill "$XVFB_PID" 2>/dev/null || true

echo "=== engine.log ==="
tail -20 "$SHOOTER_DATA_DIR/engine.log" 2>&1
