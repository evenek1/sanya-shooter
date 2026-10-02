#!/bin/sh
# Лончер для Nix-сборки Shooter.
#
# Почему он нужен: игра и движок 3dzavr грузят все ресурсы по относительным путям
# (textures/..., sound/..., obj/..., а также 3dzavr/engine/fonts/*.ttf) и пишут
# engine.log в текущий рабочий каталог. Каталог Nix store доступен только для
# чтения, поэтому игра запускается из пользовательского каталога данных, куда
# ресурсы копируются один раз при первом запуске.
#
# Переопределить каталог данных: SHOOTER_DATA_DIR=/path/to/dir shooter

set -eu

store_dir='@assets@'
default_data_dir="${XDG_DATA_HOME:-${HOME:-/tmp}/.local/share}/shooter"
data_dir="${SHOOTER_DATA_DIR:-$default_data_dir}"

mkdir -p "$data_dir"

# Копируем ресурсы только один раз, чтобы не затирать отредактированные connect.txt/server.txt.
if [ ! -d "$data_dir/textures" ] || [ ! -d "$data_dir/3dzavr" ]; then
    echo "shooter: первый запуск, копирую ресурсы в $data_dir" >&2
    cp -rT "$store_dir" "$data_dir"
    chmod -R u+w "$data_dir"
fi

cd "$data_dir"
exec "$store_dir/shooter" "$@"
