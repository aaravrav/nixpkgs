{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  easydict,
  einops,
  huggingface-hub,
  librosa,
  nnaudio,
  numpy,
  soundfile,
  torch,
  torchaudio,
  tqdm,
  transformers,
  x-clip,
}:

buildPythonPackage (finalAttrs: {
  pname = "muq";
  version = "0.1.0";
  pyproject = true;

  __structuredAttrs = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-Z+u0fSOOcCFRJT0I6D4tu76J0kxBS1tBDZs9tVxKb6g=";
  };

  build-system = [ setuptools ];

  dependencies = [
    easydict
    einops
    huggingface-hub
    librosa
    nnaudio
    numpy
    soundfile
    torch
    torchaudio
    tqdm
    transformers
    x-clip
  ];

  # The source distribution does not contain a test suite.
  doCheck = false;

  env = {
    HF_HUB_OFFLINE = "1";
    TRANSFORMERS_OFFLINE = "1";
  };

  pythonImportsCheck = [
    "muq"
  ];

  meta = {
    description = "Deep learning model for music and text";
    homepage = "https://github.com/tencent-ailab/MuQ";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = torch.meta.platforms;
  };
})
