{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  braceexpand,
  ftfy,
  h5py,
  librosa,
  llvmlite,
  numpy,
  pandas,
  progressbar2,
  regex,
  scikit-learn,
  scipy,
  soundfile,
  torch,
  torchaudio,
  torchlibrosa,
  torchvision,
  tqdm,
  transformers,
  wandb,
  webdataset,
  wget,
}:

buildPythonPackage (finalAttrs: {
  pname = "laion-clap";
  version = "1.1.7";
  pyproject = true;

  __structuredAttrs = true;

  src = fetchPypi {
    pname = "laion_clap";
    inherit (finalAttrs) version;
    hash = "sha256-mrnFI2ueCUT2fWaF7yqcFIFOvRPA2GLH/gepu1ZgQ5c=";
  };

  build-system = [ setuptools ];

  dependencies = [
    braceexpand
    ftfy
    h5py
    librosa
    llvmlite
    numpy
    pandas
    progressbar2
    regex
    scikit-learn
    scipy
    soundfile
    torch
    torchaudio
    torchlibrosa
    torchvision
    tqdm
    transformers
    wandb
    webdataset
    wget
  ];

  # Importing the module must not download unused tokenizer models.
  patches = [ ./lazy-tokenizers.patch ];

  postPatch = ''
    # progressbar2 provides the same module as the unmaintained progressbar.
    substituteInPlace pyproject.toml --replace-fail '"progressbar"' '"progressbar2"'
  '';

  pythonRelaxDeps = [ "numpy" ];

  # Importing torchlibrosa initializes numba, which needs a writable cache.
  checkPhase = ''
    runHook preCheck
    export NUMBA_CACHE_DIR="$(mktemp -d)"
    runHook postCheck
  '';

  env = {
    HF_HUB_OFFLINE = "1";
    TRANSFORMERS_OFFLINE = "1";
  };

  pythonImportsCheck = [
    "laion_clap"
  ];

  meta = {
    description = "Contrastive Language-Audio Pretraining Model from LAION";
    homepage = "https://github.com/LAION-AI/CLAP";
    license = lib.licenses.cc0;
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = torch.meta.platforms;
  };
})
