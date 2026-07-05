{
  lib,
  stdenv,
  fetchFromGitLab,
  attica,
  cmake,
  extra-cmake-modules,
  kauth,
  kcmutils,
  kconfig,
  kcoreaddons,
  kcrash,
  kdbusaddons,
  kglobalaccel,
  kguiaddons,
  ki18n,
  kiconthemes,
  kio,
  kirigami,
  kitemmodels,
  knewstuff,
  knotifications,
  knotifyconfig,
  kpackage,
  krunner,
  kstatusnotifieritem,
  ksvg,
  kwidgetsaddons,
  kwin,
  kwindowsystem,
  kxmlgui,
  libksysguard,
  libplasma,
  pkg-config,
  plasma-activities,
  plasma-activities-stats,
  plasma-wayland-protocols,
  plasma-workspace,
  plasma5support,
  qqc2-desktop-style,
  qt5compat,
  qtbase,
  qtdeclarative,
  qtsvg,
  qtwayland,
  sonnet,
  wayland,
  wrapQtAppsHook,
}:

stdenv.mkDerivation {
  pname = "aerothemeplasma";
  version = "6.7.0-unstable-2026-06-27";

  srcs = [
    (fetchFromGitLab {
      domain = "gitgud.io";
      group = "aeroshell";
      owner = "atp";
      repo = "aerothemeplasma";
      rev = "3ec84b8772392fda8f08736bbabd613f4e220853";
      hash = "sha256-uK4r19mjRzjaqOjzOAv5zR8gn4m+B67fW1/PrLEZ5rA=";
      name = "aerothemeplasma";
    })
    # Provides the aeroshell.{taskmanager,showdesktop,utils} QML modules the
    # plasmoids import at runtime
    (fetchFromGitLab {
      domain = "gitgud.io";
      owner = "aeroshell";
      repo = "aeroshell-workspace";
      rev = "00a39ba08f3b9441b0883f1b82fc4e7e9e6a44b7";
      hash = "sha256-UGT+MaFwSgLzacdwZTLhaxW5qhaSVa6ZFE6F4XCaHbE=";
      name = "aeroshell-workspace";
    })
  ];
  sourceRoot = "aerothemeplasma";

  postPatch = ''
    # Replace FHS paths with store paths
    substituteInPlace plasma/sddm/login-sessions/startatp.cmake plasma/sddm/login-sessions/startatp-wayland.cmake \
      --replace-fail "/etc/xdg/aerothemeplasma" "$out/etc/xdg/aerothemeplasma"
    substituteInPlace plasma/sddm/login-sessions/startatp-wayland.cmake \
      --replace-fail '@CMAKE_INSTALL_FULL_LIBEXECDIR@/plasma-dbus-run-session-if-needed' \
        "${plasma-workspace}/libexec/plasma-dbus-run-session-if-needed" \
      --replace-fail "\''${CMAKE_INSTALL_FULL_BINDIR}/startplasma-wayland" \
        "${lib.getBin plasma-workspace}/bin/startplasma-wayland"
    substituteInPlace misc/xdg/autostart/x-atpootb.desktop \
      --replace-fail "/usr/bin/atpootb" "$out/bin/atpootb"
    substituteInPlace plasma/atpootb/src/app.h \
      --replace-fail "/usr/share/aerothemeplasma" "$out/share/aerothemeplasma"
    substituteInPlace plasma/atpootb/src/CMakeLists.txt \
      --replace-fail "\''${CMAKE_INSTALL_PREFIX}/share/dbus-1/interfaces/org.kde.kwin.Effects.xml" \
        "${kwin}/share/dbus-1/interfaces/org.kde.kwin.Effects.xml"
    substituteInPlace plasma/shells/io.gitgud.wackyideas.desktop/contents/views/DesktopEditMode.qml \
      --replace-fail "/usr/share/sddm/themes/sddm-theme-mod" "$out/share/sddm/themes/sddm-theme-mod"

    # Bare library names only resolve headers on FHS
    sed -i \
      -e 's/^        PlasmaQuick$/        Plasma::PlasmaQuick/' \
      -e 's/^        Plasma$/        Plasma::Plasma/' \
      plasma/plasmoids/src/sevenstart_src/src/CMakeLists.txt
  '';

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    pkg-config
    wrapQtAppsHook
  ];

  buildInputs = [
    attica
    kauth
    kcmutils
    kconfig
    kcoreaddons
    kcrash
    kdbusaddons
    kglobalaccel
    kguiaddons
    ki18n
    kiconthemes
    kio
    kirigami
    kitemmodels
    knewstuff
    knotifications
    knotifyconfig
    kpackage
    krunner
    kstatusnotifieritem
    ksvg
    kwidgetsaddons
    kwin
    kwindowsystem
    kxmlgui
    libksysguard
    libplasma
    plasma-activities
    plasma-activities-stats
    plasma-wayland-protocols
    plasma-workspace
    plasma5support
    qqc2-desktop-style
    qt5compat
    qtbase
    qtdeclarative
    qtsvg
    qtwayland
    sonnet
    wayland
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
  ];

  postInstall = ''
    # Configuring with INSTALL_X11_COMPONENTS=ON installs only the X11
    # session files so install directly
    install -Dm755 ../plasma/sddm/login-sessions/startatp.cmake $out/bin/startatp
    mkdir -p $out/share/xsessions
    substitute ../plasma/sddm/login-sessions/aerothemeplasmax11.desktop.cmake \
      $out/share/xsessions/aerothemeplasmax11.desktop \
      --replace-fail "\''${CMAKE_INSTALL_FULL_BINDIR}" "$out/bin"

    # aeroshell-workspace is a separate CMake project; build it into the same
    # prefix
    cmake -S ../../aeroshell-workspace -B build-workspace \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$out $cmakeFlags
    cmake --build build-workspace -j$NIX_BUILD_CORES
    cmake --install build-workspace
  '';

  passthru.providedSessions = [
    "aerothemeplasma"
    "aerothemeplasmax11"
  ];

  meta = {
    description = "Alternative shell for KDE Plasma that aims to replicate the look and feel of Windows 7";
    longDescription = ''
      This is a project which aims to recreate the look and feel of Windows 7
      as much as possible on KDE Plasma, whilst adapting the design to fit in
      with modern features provided by KDE Plasma and Linux.

      The companion KWin components (window decorations and effects), the
      icon, sound and cursor themes, and the libplasma patches live in
      separate upstream repositories and are not included.
    '';
    homepage = "https://gitgud.io/aeroshell/atp/aerothemeplasma";
    # AGPL-3.0-only with GPL-2.0-or-later parts and LGPL-2.1-or-later KDE
    # forks; parts of the artwork are derived from Microsoft Windows
    license = with lib.licenses; [
      agpl3Only
      gpl2Plus
      lgpl21Plus
      unfree
    ];
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = lib.platforms.linux;
  };
}
