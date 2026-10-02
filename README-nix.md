# Shooter — сборка под Linux / NixOS

[Nix flake](flake.nix), который собирает [Shooter](https://github.com/vectozavr/shooter) — FPS
на движке [3dzavr](https://github.com/vectozavr/3dzavr) (SFML) — в нативный Linux-бинарь.

```bash
nix build                # -> ./result/bin/shooter
./result/bin/shooter
```

или сразу:

```bash
nix run                  # соберёт и запустит
nix run .#shooter        # то же самое по имени пакета
```

Поддерживаемые системы: `x86_64-linux`, `aarch64-linux`.

---

## Требования

* Nix с включёнными flakes:
  `experimental-features = nix-command flakes`
* Для запуска игры нужен GPU + OpenGL. На NixOS:
  ```nix
  hardware.graphics.enable = true;
  ```
* Звук (сборка линкуется с OpenAL, а также с ALSA/PulseAudio/PipeWire) — на NixOS
  достаточно `services.pipewire.enable = true;` или `sound.enable = true;`.

## Куда игра пишет данные

Движок грузит **все** ресурсы по относительным путям (`textures/...`, `sound/...`, `obj/...`
и `3dzavr/engine/fonts/*.ttf`) и пишет `engine.log` в **текущий рабочий каталог**.
Каталог Nix store доступен только для чтения, поэтому пакет ставит в `bin/shooter`
лончер, который:

1. при первом запуске копирует ресурсы в
   `${XDG_DATA_HOME:-~/.local/share}/shooter`,
2. запускает игру оттуда.

Переопределить каталог:

```bash
SHOOTER_DATA_DIR=/path/to/dir nix run
```

Файлы настроек лежат там же:

| Файл | Содержимое |
|---|---|
| `connect.txt` | `ip`  `порт`  `ник` (по одному значению на строку) |
| `server.txt` | `порт` локального сервера |

Если `connect.txt` указывает на локальный IP — игра поднимет локальный сервер, и можно
играть одному. Выделенный сервер — отдельный репозиторий
[vectozavr/shooter_server](https://github.com/vectozavr/shooter_server).

## Подключение к своей конфигурации NixOS

```nix
{
  inputs.shooter.url = "github:vectozavr/shooter";   # после того как флейк попадёт в репозиторий

  # ...
  environment.systemPackages = [
    inputs.shooter.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

## Разработка (без flake-сборки)

```bash
nix develop
git submodule update --init --recursive
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
./shooter
```

`nix develop` даёт `cmake`, `gcc`, SFML 2.x, OpenGL/GLU, freeglut и pkg-config.
Обратите внимание: бинарник кладётся в корень репозитория
(`CMAKE_RUNTIME_OUTPUT_DIRECTORY` жёстко задан в `CMakeLists.txt`).

---

## Что пришлось решать (грабли)

1. **Сабмодуль указывает не на ту ветку.** `.gitmodules` не фиксирует ветку, а `master`
   движка 3dzavr переписан на **SDL2** — с этой игрой он несовместим (код использует
   `sf::` и `<SFML/...>`). Нужна ветка `sfml_version`. Ревизия зафиксирована в флейке:
   `3af8e6c6fb8a685647ed97054392c716423e719d` (её же содержит gitlink в репозитории игры).
   В флейке движок подтягивается через `fetchgit` с этой ревизией и распаковывается в
   `3dzavr/` — именно там его ожидает `add_subdirectory(3dzavr/engine)`.

2. **В nixpkgs 25.05+ `sfml` — это SFML 3.** `nixos-unstable` отдаёт `sfml-3.0.2`,
   `nixos-25.05` — `3.0.0`; API SFML 3 несовместим с этим кодом (2021 год, `find_package(SFML 2.5.1 ...)`,
   линковка с `sfml-graphics`/`sfml-audio`/...). Поэтому в флейке используется
   **`pkgs.sfml_2`** (2.6.2). Версия 2.5.1 «из коробки» есть только в `nixos-24.11`.

3. **`CMakeLists.txt` форсит каталог вывода.** В нём стоит
   `set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")`, из-за чего бинарник
   оказывается рядом с `CMakeLists.txt`, а не в каталоге сборки. Поэтому сборка идёт
   in-source (`dontUseCmakeBuildDir = true`), иначе `installPhase` его не находит.

4. **`find_package(GLUT REQUIRED)`.** Код GLUT не использует, но `engine/CMakeLists.txt`
   на UNIX его требует — в зависимости добавлен `freeglut`.

5. **Ресурсы в read-only store.** См. раздел про лончер выше: без копирования в
   пользовательский каталог игра не стартует и не может писать `engine.log`.

## Ограничения

* **SFML 3 не поддерживается.** Обновление до SFML 3 — отдельная задача (правки API
  как минимум в `io/`, `gui/`, `utils/` движка и в игре).
* `obj/maps/railway.obj` в репозитории отсутствует, хотя константа
  `ShooterConsts::MAR_RAILWAY_OBJ` на него ссылается. Константа нигде не используется —
  на запуск не влияет, но ассет отсутствует.
* Онлайн-сервер (`shooter_server`) этим флейком не собирается — это отдельный репозиторий.
* Игре нужен рабочий OpenGL-контекст. Сборка проверена; запуск проверен частично,
  см. раздел ниже.

## Что и как проверено

Сборка выполнялась в Linux-контейнере (`nixos/nix`, `aarch64-linux`):

| Проверка | Результат |
|---|---|
| `nix build` (компиляция + линковка + installPhase) | успешно, `exit 0` |
| Тулинг | GCC 16.2.0, CMake 4.4.3, SFML 2.6.2 |
| Тип бинарника | `ELF 64-bit LSB pie executable, ARM aarch64, GNU/Linux` |
| `ldd` | 0 неразрешённых зависимостей (SFML 2.6, libglvnd, GLU, OpenAL, X11 и т.д.) |
| Содержимое пакета | бинарник, `textures` (2), `sound` (23), `obj` (18), шрифты движка (4), `connect.txt`, `server.txt` |
| Запуск лончера | ресурсы копируются в `SHOOTER_DATA_DIR` |
| Старт игры (Xvfb) | движок инициализируется и **загружает ассеты**: `Time/Timeline/ResourceManager/SoundController/EventHandler::init()`, `Mesh::LoadObjects(): obj 'obj/other/cube.obj' was loaded` |
| Создание OpenGL-контекста | **не проверено**: в headless-контейнере нет GLX |
| `x86_64-linux` | дерево замыкания **инстанцируется без ошибок** (`nix build --dry-run`: собирать нужно только сам `shooter`, всё остальное есть в бинарном кэше); полная компиляция не выполнялась — см. ниже |

Почему GL-контекст не проверен: у `Xvfb` из nixpkgs в этом окружении **нет расширения GLX**
(`xdpyinfo`: 22 расширения, `GLX` среди них отсутствует), поэтому `glxinfo -B` — штатная
утилита из `mesa-demos` — падает с `couldn't find RGB GLX visual or fbconfig`, а SFML 2.6
после неудачного `glfw`/`glx`-инициализации сегфолтится в `ensureExtensionsInit`.
Это ограничение headless-окружения, а не сборки: игру останавливает ровно отсутствие GLX,
до которого движок доходит уже после успешной инициализации и загрузки ассетов.

На реальной машине с GPU (на NixOS — с `hardware.graphics.enable = true`) GLX-контекст
создаётся штатно. Скрипт `nix/smoke-test.sh` воспроизводит эту проверку.

Почему не собрано под `x86_64-linux`: сборка шла на Apple Silicon, и запустить Nix-builder
для чужой архитектуры через QEMU не удалось — builder падает на `getting pseudoterminal
attributes: Function not implemented` (в user-mode эмуляции QEMU не реализован ioctl `TCGETS`).
Это ограничение способа верификации, а не флейка: `x86_64-linux`-дерево инстанцируется
полностью, а вся специфика проекта (патчи, ревизия движка, `sfml_2`, in-source сборка)
архитектурно-независима и проверена на `aarch64-linux`. На обычной x86_64-машине должно
собираться так же; если что-то пойдёт не так — присылайте вывод `nix build --print-build-logs`.
