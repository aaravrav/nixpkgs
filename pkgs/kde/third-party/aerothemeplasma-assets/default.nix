{
  lib,
  stdenv,
  fetchFromGitLab,
  cmake,
}:

stdenv.mkDerivation {
  pname = "aerothemeplasma-assets";
  version = "6.6.1-unstable-2026-06-20";

  srcs = [
    # Windows 7 Aero icon theme and aero-drop cursor theme
    (fetchFromGitLab {
      domain = "gitgud.io";
      group = "aeroshell";
      owner = "atp";
      repo = "aerothemeplasma-icons";
      rev = "96950b8028a5d960cb683280fe5f1d9e33e6b8a2";
      hash = "sha256-7dfoGD3LQiBQ7/JeM1CwAZ+NNMaAJyAN/SaYIHZl1xg=";
      name = "aerothemeplasma-icons";
    })
    # Windows 7 sound themes
    (fetchFromGitLab {
      domain = "gitgud.io";
      group = "aeroshell";
      owner = "atp";
      repo = "aerothemeplasma-sounds";
      rev = "55d2f5fd15f53cccbbb13388941b930442db1159";
      hash = "sha256-z73owMl2+mAQJKGgjuJAmPIYOYuoVug0nWZ3WqWY0DY=";
      name = "aerothemeplasma-sounds";
    })
  ];
  sourceRoot = "aerothemeplasma-icons";

  nativeBuildInputs = [ cmake ];

  postInstall = ''
    cmake -S ../../aerothemeplasma-sounds -B build-sounds -DCMAKE_INSTALL_PREFIX=$out
    cmake --install build-sounds
  '';

  meta = {
    description = "Icon, cursor and sound themes for AeroThemePlasma";
    homepage = "https://gitgud.io/aeroshell/atp/aerothemeplasma-icons";
    # Derived from Microsoft Windows artwork
    license = with lib.licenses; [ unfree ];
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = lib.platforms.all;
  };
}
