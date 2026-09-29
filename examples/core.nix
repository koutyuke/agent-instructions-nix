let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.inputs.nixpkgs.legacyPackages.${builtins.currentSystem};
in
flake.lib.mkBundle {
  inherit pkgs;
  insertH1.enable = true;
  fragments = [
    {
      path = ./instructions/COMMON.md;
      headingStrategy = "drop";
    }
  ];
  targets = {
    claude.enable = true;
    codex = {
      enable = true;
      fragments = [ ./instructions/CODEX.md ];
    };
  };
}
