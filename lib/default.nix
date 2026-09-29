# Core API. Depends only on nixpkgs `lib` (and `pkgs` for mkBundle), so any
# module system or script can build on it; see modules/ for adapters.
{ lib }:
let
  defaultTargets = import ./targets.nix;
  targets = import ./resolve.nix { inherit lib defaultTargets; };
  content = import ./compose.nix { inherit lib; };
  mkBundle = import ./bundle.nix {
    inherit lib;
    inherit (content) compose targetWarnings;
    inherit (targets) resolveTargets checkTargets;
  };
in
{
  inherit defaultTargets mkBundle;
  inherit (content) compose targetWarnings;
  inherit (targets) resolveTargets checkTargets;
}
