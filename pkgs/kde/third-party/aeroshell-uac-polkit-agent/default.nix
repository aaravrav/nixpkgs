{
  lib,
  stdenv,
  fetchFromGitLab,
  cmake,
  extra-cmake-modules,
  kconfig,
  kcoreaddons,
  kcrash,
  kdbusaddons,
  ki18n,
  knotifications,
  kwindowsystem,
  polkit-kde-agent-1,
  polkit-qt-1,
  qtbase,
  qtdeclarative,
  wrapQtAppsHook,
}:

stdenv.mkDerivation {
  pname = "aeroshell-uac-polkit-agent";
  version = "6.7.0-unstable-2026-06-20";

  src = fetchFromGitLab {
    domain = "gitgud.io";
    owner = "aeroshell";
    repo = "uac-polkit-agent";
    rev = "d8c2262f5a12fe1a53560e70414b9312b91d84bb";
    hash = "sha256-SltZEKT8CvCWirx00b3ZjCWv8Smc/AEppTuXhXVKQts=";
  };

  postPatch = ''
    # The plasma-polkit-agent drop-in falls back to the stock agent when the
    # session does not set USE_UAC_AGENT; point it at the real one
    substituteInPlace uac-polkit-agent.conf.in \
      --replace-fail "@KDE_INSTALL_FULL_LIBEXECDIR@/polkit-kde-authentication-agent-1" \
        "${polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1"
  '';

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    wrapQtAppsHook
  ];

  buildInputs = [
    kconfig
    kcoreaddons
    kcrash
    kdbusaddons
    ki18n
    knotifications
    kwindowsystem
    polkit-qt-1
    qtbase
    qtdeclarative
  ];

  meta = {
    description = "Polkit authentication agent for AeroThemePlasma styled after the Windows UAC dialogs";
    homepage = "https://gitgud.io/aeroshell/uac-polkit-agent";
    license = with lib.licenses; [
      gpl2Plus
      cc0
    ];
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = lib.platforms.linux;
  };
}
