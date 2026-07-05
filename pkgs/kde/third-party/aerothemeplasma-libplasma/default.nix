{
  lib,
  fetchFromGitLab,
  libplasma,
}:

(libplasma.overrideAttrs (old: {
  pname = "aerothemeplasma-libplasma";
  version = "6.7.2-unstable-2026-07-04";

  src = fetchFromGitLab {
    domain = "gitgud.io";
    owner = "aeroshell";
    repo = "libplasma";
    rev = "9205864b21ac92a90e6a948b443f29daa2913fd4";
    hash = "sha256-CEk3jsvZTGmgQZtCi6Pp26NtZjypqh0ZgWf9UcjwVhc=";
  };

  # The fork maintains its own tree; drop patches meant for the pristine release
  patches = [ ];

  meta = old.meta // {
    description = "Fork of libplasma with Aero glass and reflection effects for AeroThemePlasma";
    longDescription = ''
      Drop-in replacement for libplasma carrying the AeroThemePlasma
      translucency, blur and reflection patches. Never used by default; opt in
      by replacing libplasma in the package set, which rebuilds everything
      depending on it:

      ```nix
      nixpkgs.overlays = [
        (final: prev: {
          kdePackages = prev.kdePackages.overrideScope (
            _: kp: { libplasma = kp.aerothemeplasma-libplasma; }
          );
        })
      ];
      ```
    '';
    homepage = "https://gitgud.io/aeroshell/libplasma";
    maintainers = with lib.maintainers; [ aaravrav ];
  };
}))
