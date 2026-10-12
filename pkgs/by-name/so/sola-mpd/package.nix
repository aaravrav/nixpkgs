{
  lib,
  nixosTests,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_10,
  pnpmConfigHook,
  nodejs_24,
  nodejs-slim_24,
  node-gyp,
  python3,
  jq,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  imagemagick,
  electron_44,
  xvfb-run,
  callPackage,
  nix-update-script,
  desktopSupport ? true,
  webSupport ? true,
  lainbowEndpoint ? null,
}:
let
  desktopId = "io.github.prokosna.solampd";
  nodejs = nodejs_24;
  pnpm = pnpm_10.override { nodejs-slim = nodejs-slim_24; };
  # Upstream's Electron 41 is EOL; the desktop bundle has no native addons.
  electron = electron_44;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sola-mpd";
  version = "4.11.0";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "prokosna";
    repo = "sola_mpd";
    tag = "v${finalAttrs.version}";
    hash = "sha256-FOGTaK5odKHR2nh6r+vMS4ymGIvMjxHRSG+cLZPpIbs=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      postPatch
      ;
    inherit pnpm;
    nativeBuildInputs = [ jq ];
    fetcherVersion = 4;
    hash = "sha256-TBDnXZYYT2PxuRdOta5/zh1fv0vVaK8VVrAyT170Mas=";
  };

  patches =
    lib.optional desktopSupport ./desktop-icon.patch ++ lib.optional webSupport ./listen-address.patch;

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    jq
    makeWrapper
  ]
  ++ lib.optionals webSupport [
    node-gyp
    python3
  ]
  ++ lib.optionals desktopSupport [
    copyDesktopItems
    imagemagick
  ];

  buildInputs = lib.optional webSupport nodejs ++ lib.optional desktopSupport electron;

  nativeInstallCheckInputs = [ xvfb-run ];

  env = {
    CI = "true";
    npm_config_nodedir = nodejs;
  }
  // lib.optionalAttrs (lainbowEndpoint != null) {
    # Upstream's advanced-search endpoint is embedded by Vite at build time.
    VITE_LAINBOW_ENDPOINT = lainbowEndpoint;
  };

  doCheck = true;
  doInstallCheck = desktopSupport && stdenv.hostPlatform.isLinux;

  postPatch = ''
    # Use the packaged Node.js instead of pnpm downloading its own runtime.
    jq 'del(.pnpm.executionEnv)' package.json > package.json.tmp
    mv package.json.tmp package.json
  '';

  buildPhase = ''
    runHook preBuild

    pnpm --filter @sola_mpd/shared build
    pnpm --filter @sola_mpd/frontend build
  ''
  + lib.optionalString webSupport ''
    # The pnpm hook skips lifecycle scripts; build SQLite against Node.js locally.
    pnpm --filter @sola_mpd/backend exec node-gyp rebuild --jobs "$NIX_BUILD_CORES" --directory node_modules/better-sqlite3
    pnpm --filter @sola_mpd/backend build
  ''
  + lib.optionalString desktopSupport ''
    pnpm --filter @sola_mpd/desktop build
  ''
  + ''
    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck

    pnpm --filter @sola_mpd/shared test --maxWorkers "$NIX_BUILD_CORES"
    pnpm --filter @sola_mpd/frontend test --maxWorkers "$NIX_BUILD_CORES"
  ''
  + lib.optionalString webSupport ''
    pnpm --filter @sola_mpd/backend test --maxWorkers "$NIX_BUILD_CORES"
  ''
  + lib.optionalString desktopSupport ''
    pnpm --filter @sola_mpd/desktop test --maxWorkers "$NIX_BUILD_CORES"
  ''
  + ''
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/sola-mpd/packages/frontend"
    cp -r packages/frontend/dist "$out/lib/sola-mpd/packages/frontend/"
    install -Dm644 LICENSE "$out/share/licenses/sola-mpd/LICENSE"
  ''
  + lib.optionalString webSupport ''
    # Use the shared lockfile instead of resolving workspace dependency ranges again.
    pnpm --config.inject-workspace-packages=true --filter @sola_mpd/backend \
      deploy --prod --offline --ignore-scripts "$out/lib/sola-mpd/packages/backend"
    # Deployment metadata contains timestamps and temporary store/source paths.
    rm "$out/lib/sola-mpd/packages/backend/pnpm-lock.yaml" \
      "$out/lib/sola-mpd/packages/backend/node_modules/.modules.yaml" \
      "$out/lib/sola-mpd/packages/backend/node_modules/.pnpm/lock.yaml" \
      "$out/lib/sola-mpd/packages/backend/node_modules/.pnpm-workspace-state-v1.json"
    cp packages/backend/package.json "$out/lib/sola-mpd/packages/backend/package.json"

    # deploy reinstalls dependencies from the store without locally built addons.
    install -Dm755 packages/backend/node_modules/better-sqlite3/build/Release/better_sqlite3.node \
      "$out/lib/sola-mpd/packages/backend/node_modules/better-sqlite3/build/Release/better_sqlite3.node"
    ln -s ../../frontend/dist "$out/lib/sola-mpd/packages/backend/dist/public"

    makeWrapper ${lib.getExe nodejs} "$out/bin/sola-mpd-server" \
      --add-flags "$out/lib/sola-mpd/packages/backend/dist/index.mjs"
  ''
  + lib.optionalString desktopSupport ''
    mkdir -p "$out/lib/sola-mpd/packages/desktop"
    cp -r packages/desktop/dist "$out/lib/sola-mpd/packages/desktop/"
    jq --arg version "$version" --arg desktopName "${desktopId}.desktop" \
      '.version = $version | .desktopName = $desktopName' packages/desktop/package.json \
      > "$out/lib/sola-mpd/packages/desktop/package.json"

    makeWrapper ${lib.getExe electron} "$out/bin/sola-mpd" \
      --add-flags "$out/lib/sola-mpd/packages/desktop" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --inherit-argv0

    # Use a size declared by the hicolor theme so desktop icon lookup works.
    mkdir -p "$out/share/icons/hicolor/512x512/apps"
    magick packages/desktop/build/icon.png -resize 512x512 -strip \
      "$out/share/icons/hicolor/512x512/apps/sola-mpd.png"
    ln -s "$out/share/icons/hicolor/512x512/apps/sola-mpd.png" \
      "$out/lib/sola-mpd/packages/desktop/icon.png"
  ''
  + ''
    runHook postInstall
  '';

  desktopItems = lib.optional desktopSupport (makeDesktopItem {
    name = desktopId;
    desktopName = "Sola MPD";
    comment = finalAttrs.meta.description;
    exec = "sola-mpd";
    icon = "sola-mpd";
    startupWMClass = desktopId;
    terminal = false;
    categories = [
      "AudioVideo"
      "Audio"
      "Player"
    ];
  });

  installCheckPhase = ''
    runHook preInstallCheck

    # Exercise the installed launcher, renderer, preload and IPC bridge.
    substituteInPlace packages/desktop/e2e/smoke.test.ts \
      --replace-fail 'args: ["--no-sandbox", mainEntry],' \
        'executablePath: "'"$out"'/bin/sola-mpd", args: ["--no-sandbox"],'
    cat ${./tests/advanced-search.test.ts} packages/desktop/e2e/smoke.test.ts \
      > packages/desktop/e2e/smoke.test.ts.tmp
    mv packages/desktop/e2e/smoke.test.ts.tmp packages/desktop/e2e/smoke.test.ts
    # The default 640x480 Xvfb screen collapses the sidebar to icon-only mode.
    xvfb-run --auto-servernum --server-args="-screen 0 1920x1080x24" \
      pnpm --filter @sola_mpd/desktop exec playwright test

    runHook postInstallCheck
  '';

  passthru = {
    tests = {
      nixos = nixosTests.sola-mpd;
    }
    // lib.optionalAttrs webSupport {
      web = callPackage ./tests {
        package = finalAttrs.finalPackage;
        inherit nodejs;
      };
    }
    // lib.optionalAttrs desktopSupport {
      # Enable the frontend against the local mock in the installed GUI tests.
      advancedSearch = finalAttrs.finalPackage.overrideAttrs {
        env = finalAttrs.env // {
          VITE_LAINBOW_ENDPOINT = "http://127.0.0.1:18888";
        };
      };
    };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "MPD client";
    homepage = "https://github.com/prokosna/sola_mpd";
    changelog = "https://github.com/prokosna/sola_mpd/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aaravrav ];
    mainProgram = if desktopSupport then "sola-mpd" else "sola-mpd-server";
    platforms = lib.intersectLists lib.platforms.linux (
      if desktopSupport then electron.meta.platforms else nodejs.meta.platforms
    );
    broken = !desktopSupport && !webSupport;
  };
})
