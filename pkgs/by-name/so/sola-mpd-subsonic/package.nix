{
  lib,
  nixosTests,
  stdenvNoCC,
  sola-mpd,
  nodejs_24,
  nodejs-slim_24,
  pnpm_10,
  pnpmConfigHook,
  jq,
  makeWrapper,
}:
let
  nodejs = nodejs_24;
  pnpm = pnpm_10.override { nodejs-slim = nodejs-slim_24; };
in
stdenvNoCC.mkDerivation {
  pname = "sola-mpd-subsonic";
  # Distributed in the Sola MPD monorepo; follow its release and lockfile.
  inherit (sola-mpd)
    version
    src
    pnpmDeps
    postPatch
    ;

  __structuredAttrs = true;
  strictDeps = true;

  patches = [ ./listen-address.patch ];

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    jq
    makeWrapper
  ];

  env.CI = "true";

  buildPhase = ''
    runHook preBuild
    pnpm --filter @sola_mpd/shared build
    pnpm --filter subsonic build
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    pnpm --filter @sola_mpd/shared test --maxWorkers "$NIX_BUILD_CORES"
    pnpm --filter subsonic test --maxWorkers "$NIX_BUILD_CORES"
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    pnpm --config.inject-workspace-packages=true --filter subsonic \
      deploy --prod --offline --ignore-scripts "$out/lib/sola-mpd-subsonic"
    # Remove deployment timestamps and temporary store/source paths.
    rm "$out/lib/sola-mpd-subsonic/pnpm-lock.yaml" \
      "$out/lib/sola-mpd-subsonic/node_modules/.modules.yaml" \
      "$out/lib/sola-mpd-subsonic/node_modules/.pnpm/lock.yaml" \
      "$out/lib/sola-mpd-subsonic/node_modules/.pnpm-workspace-state-v1.json"

    makeWrapper ${lib.getExe nodejs} "$out/bin/sola-mpd-subsonic" \
      --add-flags "$out/lib/sola-mpd-subsonic/dist/index.mjs" \
      --set npm_package_version "$(node -p 'require("./plugins/subsonic/package.json").version')"
    install -Dm644 LICENSE "$out/share/licenses/sola-mpd-subsonic/LICENSE"

    runHook postInstall
  '';

  passthru.tests.nixos = nixosTests.sola-mpd;

  meta = {
    description = "Plugin to synchronize songs with a Subsonic playlist";
    homepage = "https://github.com/prokosna/sola_mpd";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aaravrav ];
    mainProgram = "sola-mpd-subsonic";
    platforms = nodejs.meta.platforms;
  };
}
