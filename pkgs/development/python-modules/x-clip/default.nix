{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  beartype,
  einops,
  ftfy,
  regex,
  torch,
  torchvision,
}:

buildPythonPackage (finalAttrs: {
  pname = "x-clip";
  version = "0.14.4";
  pyproject = true;

  __structuredAttrs = true;

  src = fetchPypi {
    inherit (finalAttrs) pname version;
    hash = "sha256-4lOZU/HIGiq4koQ8K8AsIY9KxBDPEM43SVgw9qDiWcY=";
  };

  build-system = [ setuptools ];

  dependencies = [
    beartype
    einops
    ftfy
    regex
    torch
    torchvision
  ];

  # The source distribution does not contain a test suite.
  doCheck = false;

  pythonImportsCheck = [
    "x_clip"
    "x_clip.tokenizer"
  ];

  meta = {
    description = "Concise but complete implementation of CLIP with various experimental improvements from recent papers";
    homepage = "https://github.com/lucidrains/x-clip";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aaravrav ];
    platforms = torch.meta.platforms;
  };
})
