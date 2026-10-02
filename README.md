# Саня Шутер

Игра **Shooter** — FPS на движке [3dzavr](https://github.com/vectozavr/3dzavr) (SFML) — плюс
**Nix-сборка**. Репозиторий самодостаточный: исходники игры и движка лежат вместе, ничего
докачивать не нужно.

Оригинал: <https://github.com/vectozavr/shooter> (MIT, Ivan Ilin / vectozavr).
Описание оригинала — в [README-upstream.md](README-upstream.md).

---

## Быстрый старт

```bash
git clone https://github.com/evenek1/sanya-shooter && cd sanya-shooter
nix build
./result/bin/shooter
```

Без ручного клонирования:

```bash
nix run "git+https://github.com/evenek1/sanya-shooter"
```

Нужно:

* Linux (x86_64 или aarch64);
* Nix с включёнными flakes:
  ```ini
  # ~/.config/nix/nix.conf (или /etc/nix/nix.conf)
  experimental-features = nix-command flakes
  ```
* рабочий OpenGL (GPU или софтверный llvmpipe);
* на NixOS дополнительно:
  ```nix
  hardware.graphics.enable = true;
  ```

**Первый запуск** сам разложит ресурсы в `~/.local/share/shooter` и стартует оттуда
(в Nix store писать нельзя). Настройки — там же:

| Файл | Что внутри |
|---|---|
| `~/.local/share/shooter/connect.txt` | `ip` · `порт` · `ник` (по одному значению на строку) |
| `~/.local/share/shooter/server.txt` | `порт` локального сервера |

Если в `connect.txt` указан локальный адрес, игра поднимет локальный сервер — можно играть
одному. Лог: `~/.local/share/shooter/engine.log`.

Другой каталог данных:

```bash
SHOOTER_DATA_DIR=/path/to/dir ./result/bin/shooter
```

Управление: `WASD` + мышь; `Space` — прыжок; `Shift` — слоу-мо; `E`/`Q` — смена оружия;
`R` — перезарядка; `O` — вкл/выкл OpenGL-рендер; `Tab` — debug-панель.

---

## Что в репозитории

```
.
├── flake.nix                 # сборка (x86_64-linux, aarch64-linux) + devShell
├── flake.lock                # зафиксированный nixpkgs
├── README.md                 # этот файл
├── README-upstream.md        # оригинальный README игры
├── nix/
│   ├── shooter-launcher.sh   # раскладывает ассеты в записываемый каталог и запускает игру
│   └── smoke-test.sh         # дымовой тест рантайма под Xvfb
├── 3dzavr/                   # движок 3dzavr целиком: ветка sfml_version, ревизия 3af8e6c
└── ...                       # исходники игры, текстуры, звуки, obj-модели
```

Полезные команды:

```bash
nix run .#shooter      # то же, что nix run
nix develop            # окружение: cmake, gcc, SFML 2, OpenGL/GLU, freeglut, pkg-config
nix flake show         # список выходов
```

Ручная сборка без flake-пакета:

```bash
nix develop
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
./shooter
```

## Подключение в конфигурацию NixOS

```nix
{
  inputs.sanya-shooter.url = "github:evenek1/sanya-shooter";

  # ...
  environment.systemPackages = [
    inputs.sanya-shooter.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

---

## Что пришлось решать (грабли)

1. **Движок вложен в репозиторий целиком.** Оригинальный репозиторий игры держит движок
   сабмодулем, причём `.gitmodules` не фиксирует ветку, а `master` движка переписан на
   **SDL2** — с этой игрой он несовместим (код использует `sf::` и `<SFML/...>`). Нужна
   ветка `sfml_version`. Здесь движок вложен обычными файлами на ревизии
   `3af8e6c6fb8a685647ed97054392c716423e719d` — именно её содержит gitlink в оригинале.
   `git clone` даёт сразу всё, без `--recursive`.

2. **В nixpkgs 25.05+ `sfml` — это SFML 3.** `nixos-unstable` отдаёт `sfml-3.0.2`,
   `nixos-25.05` — `3.0.0`; API SFML 3 несовместим с этим кодом (2021 год,
   `find_package(SFML 2.5.1 ...)`, линковка с `sfml-graphics`/`sfml-audio`/...).
   Поэтому используется **`pkgs.sfml_2`** (2.6.2). Версия 2.5.1 «из коробки» есть только
   в `nixos-24.11`.

3. **`CMakeLists.txt` форсит каталог вывода.** В нём стоит
   `set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")`, из-за чего бинарник
   оказывается рядом с `CMakeLists.txt`, а не в каталоге сборки. Поэтому сборка идёт
   in-source (`dontUseCmakeBuildDir = true`), иначе `installPhase` его не находит.

4. **`find_package(GLUT REQUIRED)`.** Код GLUT не использует, но
   `3dzavr/engine/CMakeLists.txt` на UNIX его требует — в зависимости добавлен `freeglut`.

5. **Ресурсы в read-only store.** Движок грузит ассеты по относительным путям и пишет
   `engine.log` в текущий каталог. Поэтому пакет ставит в `bin/shooter` лончер, который
   копирует ресурсы в `~/.local/share/shooter` и запускает игру оттуда.

## Ограничения

* **SFML 3 не поддерживается.** Переход на SFML 3 — отдельная задача.
* `ShooterConsts::MAR_RAILWAY_OBJ` ссылается на `obj/maps/railway.obj`, которого нет
  в оригинальном репозитории. Константа нигде не используется — на запуск не влияет.
* Выделенный сервер (`shooter_server`) — отдельный проект, здесь не собирается.
* Игре нужен рабочий OpenGL-контекст.

## Что и как проверено

Сборка: `nix build` в Linux-контейнере (`nixos/nix`, `aarch64-linux`), GCC 16.2.0,
CMake 4.4.3, SFML 2.6.2. Nix берёт в flake только отслеживаемые git-файлы, поэтому
успешная сборка заодно доказывает, что вложенного набора файлов достаточно.

| Проверка | Результат |
|---|---|
| `nix build` (компиляция + линковка + installPhase) | успешно, `exit 0` |
| Тип бинарника | `ELF 64-bit LSB pie executable, ARM aarch64, GNU/Linux` |
| `ldd` | 0 неразрешённых зависимостей (SFML 2.6, libglvnd, GLU, OpenAL, X11 и т.д.) |
| Содержимое пакета | бинарник, `textures` (2), `sound` (23), `obj` (18), шрифты движка (4), `connect.txt`, `server.txt` |
| Запуск лончера | ресурсы копируются в `SHOOTER_DATA_DIR` |
| Старт игры (Xvfb) | движок инициализируется и загружает ассеты: `Time/Timeline/ResourceManager/SoundController/EventHandler::init()`, `Mesh::LoadObjects(): obj 'obj/other/cube.obj' was loaded` |
| Создание OpenGL-контекста | **не проверено**: в headless-контейнере нет расширения GLX |
| `x86_64-linux` | дерево замыкания инстанцируется без ошибок (`nix build --dry-run`: собирать нужно только сам `shooter`); полная компиляция не выполнялась |

Почему GL-контекст не проверен: у `Xvfb` из nixpkgs в этом окружении **нет расширения GLX**
(`xdpyinfo`: 22 расширения, `GLX` отсутствует), поэтому штатный `glxinfo` из `mesa-demos`
падает с `couldn't find RGB GLX visual or fbconfig`, а SFML 2.6 после неудачной
инициализации сегфолтится в `ensureExtensionsInit`. Это ограничение headless-окружения,
а не сборки: движок доходит до GL уже после успешной инициализации и загрузки ассетов.
На машине с GPU контекст создаётся штатно. Проверку воспроизводит `nix/smoke-test.sh`.

Почему не собрано под `x86_64-linux`: сборка шла на Apple Silicon, и запустить Nix-builder
для чужой архитектуры через QEMU не удалось — builder падает на
`getting pseudoterminal attributes: Function not implemented` (в user-mode эмуляции QEMU
не реализован ioctl `TCGETS`). Дерево зависимостей для x86_64 при этом резолвится полностью,
а вся специфика проекта архитектурно-независима и проверена на `aarch64-linux`.

---

## Лицензия и авторство

Код игры и движка — MIT, автор оригинала: Ivan Ilin
([vectozavr](https://github.com/vectozavr)). Сохранены `LICENSE` и `3dzavr/LICENSE`.
Добавлено здесь: `flake.nix`, `flake.lock`, `nix/`, документация.
