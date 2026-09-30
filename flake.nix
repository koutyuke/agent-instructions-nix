{
  description = "Compose and manage shared instructions for AI coding agents with Nix and Home Manager.";

  # Keep nixpkgs as the only input. Home Manager adapter tests live in ./dev.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      core = import ./lib { inherit (nixpkgs) lib; };
    in
    {
      lib = core;

      homeManagerModules.default = ./modules/home-manager.nix;

      checks = forAllSystems (
        system:
        import ./test/core.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit core;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
