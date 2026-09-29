{
  lib,
  resolveTargets,
  checkTargets,
  compose,
  targetWarnings,
}:
let
  # Build a bundle containing the composed content in $out/<target>.md.
  mkBundle =
    {
      pkgs,
      fragments ? [ ],
      insertH1 ? { },
      targets ? { },
      name ? "agent-instructions",
    }:
    let
      resolved = resolveTargets { inherit fragments insertH1 targets; };
      errors = checkTargets resolved;
    in
    if errors != [ ] then
      throw "agent-instructions:\n${lib.concatMapStringsSep "\n" (e: "- ${e}") errors}"
    else
      lib.showWarnings (map (w: "agent-instructions: ${w}") (targetWarnings resolved)) (
        pkgs.linkFarm name (
          lib.mapAttrsToList (target: t: {
            name = "${target}.md";
            path = pkgs.writeText "agent-instructions-${target}.md" (compose t);
          }) resolved
        )
      );
in
mkBundle
