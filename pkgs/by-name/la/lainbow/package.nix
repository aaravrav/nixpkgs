{
  lib,
  fetchFromGitHub,
  ffmpeg,
  nix-update-script,
  nixosTests,
  python313,
}:

python313.pkgs.buildPythonApplication {
  pname = "lainbow";
  version = "0.1.0-unstable-2026-01-03";
  pyproject = true;

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "prokosna";
    repo = "lainbow";
    rev = "600efa151c32b835827c31e33260202f793cb912";
    hash = "sha256-i3zojdk2cr38SwqmjWbsOi1fz/fO3RH70nkbaLV9mHo=";
  };

  patches = [
    # Make container-specific paths and database URLs configurable for native services.
    ./runtime-paths.patch
    # Avoid deprecated transient non-exclusive queues with current RabbitMQ.
    ./rabbitmq-queues.patch
  ];

  build-system = [ python313.pkgs.setuptools ];

  dependencies = with python313.pkgs; [
    celery
    fastapi
    httpx
    laion-clap
    librosa
    mutagen
    muq
    numpy
    pika
    psycopg
    psycopg2
    pydantic
    python-multipart
    qdrant-client
    sqlalchemy
    sqlmodel
    tenacity
    torch
    torchaudio
    transformers
    uvicorn
    zstandard
  ];

  postPatch = ''
    # Extend the upstream cap to the Python 3.13 runtime tested below.
    substituteInPlace pyproject.toml --replace-fail '>=3.12,<3.13' '>=3.12,<3.14'
    cp ${./cli.py} src/lainbow_cli.py
    cat >> pyproject.toml <<'TOML'

    [build-system]
    requires = ["setuptools"]
    build-backend = "setuptools.build_meta"

    [tool.setuptools]
    package-dir = {"" = "src"}
    py-modules = ["lainbow_cli"]

    [tool.setuptools.packages.find]
    where = ["src"]

    [project.scripts]
    lainbow-api = "lainbow_cli:api"
    lainbow-inference = "lainbow_cli:inference"
    lainbow-worker = "lainbow_cli:worker"
    TOML
  '';

  # No models or tokenizers are fetched by the package or its entry points.
  makeWrapperArgs = [
    "--set"
    "HF_HUB_OFFLINE"
    "1"
    "--set"
    "TRANSFORMERS_OFFLINE"
    "1"
    "--set"
    "HF_HUB_DISABLE_TELEMETRY"
    "1"
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [ ffmpeg ])
  ];

  nativeCheckInputs = [ python313.pkgs.pytestCheckHook ];

  env = {
    HF_HUB_OFFLINE = "1";
    TRANSFORMERS_OFFLINE = "1";
  };

  preCheck = ''
    export NUMBA_CACHE_DIR="$(mktemp -d)"
    # Upstream mocks model loading but still checks these paths exist.
    mkdir -p models/MERT-v1-330M
    touch models/music_audioset_epoch_15_esc_90.14.pt
  '';

  pythonImportsCheck = [
    "api.main"
    "inference.main"
    "worker.celery_app"
  ];

  postInstallCheck = ''
    $out/bin/lainbow-api --help >/dev/null
    $out/bin/lainbow-inference --help >/dev/null
    $out/bin/lainbow-worker --help >/dev/null
  '';

  passthru = {
    tests.nixos = nixosTests.lainbow;
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Music analysis engine designed to process local music libraries";
    homepage = "https://github.com/prokosna/lainbow";
    # Local draft: upstream has not provided a license; deliberately unset.
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = [ "x86_64-linux" ];
  };
}
