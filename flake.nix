{
  description = "Саня Шутер — сборка Shooter (3dzavr / SFML) под Linux и NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          lib = pkgs.lib;

          shooter = pkgs.stdenv.mkDerivation (finalAttrs: {
            pname = "shooter";
            version = "0.1.0-unstable";

            # Исходники игры + движок 3dzavr лежат вместе в этом репозитории
            # (движок в 3dzavr/, ветка sfml_version, ревизия 3af8e6c).
            src = ./.;

            nativeBuildInputs = [ pkgs.cmake ];

            buildInputs = [
              # Игра (2021) и движок 3dzavr написаны под SFML 2.x: `find_package(SFML 2.5.1 ...)`
              # и линковка с таргетами sfml-graphics/sfml-audio/...
              # В nixpkgs 25.05+ пакет `sfml` — это уже SFML 3 с несовместимым API,
              # поэтому явно берём `sfml_2` (2.6.x).
              pkgs.sfml_2
              # OpenGL + GLU + GLUT (движок на UNIX требует find_package(GLUT REQUIRED)).
              # X11/OpenAL/OpenGL-зависимости SFML приходят через propagatedBuildInputs.
              pkgs.libGL
              pkgs.libGLU
              pkgs.freeglut
            ];

            # sanity-check: CMakeLists.txt делает add_subdirectory(3dzavr/engine)
            preConfigure = ''
              test -f 3dzavr/engine/CMakeLists.txt || {
                echo "3dzavr/engine/CMakeLists.txt not found — движок не вложен в репозиторий"
                exit 1
              }
            '';

            cmakeFlags = [
              "-DCMAKE_BUILD_TYPE=Release"
            ];

            # CMakeLists.txt игры принудительно кладёт бинарник в каталог исходников
            # (set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ...)), поэтому собираем in-source,
            # а не в подкаталоге build/ — иначе installPhase его не найдёт.
            dontUseCmakeBuildDir = true;

            # Игра не имеет install-правил, раскладываем всё руками.
            # layout: $out/libexec/shooter — «рабочий каталог» игры (двоичник + ресурсы).
            installPhase = ''
              runHook preInstall

              mkdir -p $out/libexec/shooter
              install -m755 shooter $out/libexec/shooter/shooter

              cp -r textures sound obj $out/libexec/shooter/

              # шрифты движка грузятся по пути 3dzavr/engine/fonts/*.ttf
              mkdir -p $out/libexec/shooter/3dzavr/engine/fonts
              cp 3dzavr/engine/fonts/*.ttf $out/libexec/shooter/3dzavr/engine/fonts/

              install -m644 connect.txt $out/libexec/shooter/connect.txt
              install -m644 server.txt $out/libexec/shooter/server.txt

              mkdir -p $out/bin
              substitute ${./nix/shooter-launcher.sh} $out/bin/shooter \
                --subst-var-by assets "$out/libexec/shooter"
              chmod +x $out/bin/shooter

              runHook postInstall
            '';

            meta = {
              description = "Shooter — first person shooter на движке 3dzavr (SFML)";
              homepage = "https://github.com/vectozavr/shooter";
              license = lib.licenses.mit;
              mainProgram = "shooter";
              platforms = lib.platforms.linux;
            };
          });
        in
        {
          inherit shooter;
          default = shooter;
        }
      );

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/shooter";
        };
        shooter = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.shooter}/bin/shooter";
        };
      });

      # nix develop — окружение для сборки обычным cmake прямо в дереве репозитория.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.cmake
            pkgs.ninja
            pkgs.gcc
            pkgs.sfml_2
            pkgs.libGL
            pkgs.libGLU
            pkgs.freeglut
            pkgs.pkg-config
          ];
        };
      });
    };
}
