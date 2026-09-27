{
  description = "Development checks for agent-instructions-nix that need Home Manager";

  inputs = {
    agent-instructions.url = "path:..";
    nixpkgs.follows = "agent-instructions/nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      agent-instructions,
      nixpkgs,
      home-manager,
      ...
    }:
    {
      checks =
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
          ]
          (
            system:
            import ../test/home-manager.nix {
              pkgs = nixpkgs.legacyPackages.${system};
              inherit home-manager;
              module = agent-instructions.homeManagerModules.default;
            }
          );
    };
}
