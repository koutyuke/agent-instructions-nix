# Core API. Depends only on nixpkgs `lib` (and `pkgs` for mkBundle), so any
# module system or script can build on it; see modules/ for adapters.
{ lib }:
let
  defaultTargets = import ./targets.nix;
  targets = import ./resolve.nix { inherit lib defaultTargets; };
  compose = import ./compose.nix { inherit lib; };
  mkBundle = import ./bundle.nix {
    inherit lib compose;
    inherit (targets) resolveTargets checkTargets;
  };
in
{
  inherit defaultTargets compose mkBundle;
  inherit (targets) resolveTargets checkTargets;
}
