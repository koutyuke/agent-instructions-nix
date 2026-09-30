# The README's Home Manager example built with the core API, so the output can
# be checked without Home Manager. Run from the repository root:
#   nix build --impure --file ./example
let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
in
flake.lib.mkBundle {
  inherit pkgs;
  sources = [
    ./COMMON.md
    {
      path = ./CONTEXT7.md;
      headingStrategy = "demote";
    }
  ];
  targets = {
    claude.enable = true;
    codex = {
      enable = true;
      sources = [
        {
          path = ./CODEX.md;
          headingStrategy = "drop";
        }
      ];
    };
  };
  insertH1.enable = true;
}
