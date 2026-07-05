{
  lib,
  stdenv,
  fetchFromGitLab,
  cmake,
  extra-cmake-modules,
  kcmutils,
  kcolorscheme,
  kconfig,
  kconfigwidgets,
  kcoreaddons,
  kcrash,
  kdecoration,
  kguiaddons,
  ki18n,
  kiconthemes,
  kio,
  kirigami,
  knotifications,
  kservice,
  ksvg,
  kwidgetsaddons,
  kwin,
  kwin-x11,
  kwindowsystem,
  libepoxy,
  libx11,
  libxcb,
  pkg-config,
  qtbase,
  qtdeclarative,
  qttools,
  qtwayland,
  vulkan-headers,
  vulkan-loader,
  wayland-protocols,
  wrapQtAppsHook,
}:

stdenv.mkDerivation {
  pname = "aerothemeplasma-kwin";
  version = "6.7.0-unstable-2026-07-05";

  srcs = [
    # SMOD window decoration and glow effect
    (fetchFromGitLab {
      domain = "gitgud.io";
      owner = "aeroshell";
      repo = "smod";
      rev = "a200d000791c53712d79cc9349a67631707c7e85";
      hash = "sha256-yCYGf918YVddFpcCT5CMmyLg5gQ0Y/rDRklk9BL2aSM=";
      name = "smod";
    })
    # C++/JS KWin effects, scripts, task switchers, window outline
    (fetchFromGitLab {
      domain = "gitgud.io";
      owner = "aeroshell";
      repo = "aeroshell-kwin-components";
      rev = "994ecfb9c4d13bae28532556df0ab734e2c99ccb";
      hash = "sha256-vLY/eYU5I7CBKp8Scz34YOCoMEjfn00FRtiJQzuMLfg=";
      name = "aeroshell-kwin-components";
    })
  ];
  sourceRoot = "smod";

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    pkg-config
    wrapQtAppsHook
  ];

  buildInputs = [
    kcmutils
    kcolorscheme
    kconfig
    kconfigwidgets
    kcoreaddons
    kcrash
    kdecoration
    kguiaddons
    ki18n
    kiconthemes
    kio
    kirigami
    knotifications
    kservice
    ksvg
    kwidgetsaddons
    kwin
    kwin-x11
    kwindowsystem
    libepoxy
    libx11
    libxcb
    qtbase
    qtdeclarative
    qttools
    qtwayland
    vulkan-headers
    vulkan-loader
    wayland-protocols
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
  ];

  postInstall = ''
    # smodglow consumes the smoddecoration.pc installed above
    export PKG_CONFIG_PATH=$out/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}

    buildExtra() {
      cmake -S "$1" -B "$2" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$out $cmakeFlags "''${@:3}"
      cmake --build "$2" -j$NIX_BUILD_CORES
      cmake --install "$2"
    }

    buildExtra ../smodglow build-smodglow-wayland -DKWIN_BUILD_WAYLAND=ON
    buildExtra ../smodglow build-smodglow-x11 -DKWIN_BUILD_WAYLAND=OFF
    buildExtra ../../aeroshell-kwin-components build-kwin-wayland -DKWIN_BUILD_WAYLAND=ON
    buildExtra ../../aeroshell-kwin-components build-kwin-x11 -DKWIN_BUILD_WAYLAND=OFF -DKWIN_INSTALL_MISC=OFF

    # kwin-x11 looks the scripted components up under share/kwin-x11
    ln -s kwin $out/share/kwin-x11
  '';

  meta = {
    description = "SMOD window decorations and KWin effects for AeroThemePlasma";
    homepage = "https://gitgud.io/aeroshell/aeroshell-kwin-components";
    # AGPL-3.0-only with GPL-2.0-or-later (Breeze fork) and GPL-3.0 (effect
    # forks) parts; parts of the artwork are derived from Microsoft Windows
    license = with lib.licenses; [
      agpl3Only
      gpl2Plus
      gpl3Only
      unfree
    ];
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = lib.platforms.linux;
  };
}
