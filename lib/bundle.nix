{
  lib,
  resolveTargets,
  checkTargets,
  compose,
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
      pkgs.linkFarm name (
        lib.mapAttrsToList (target: t: {
          name = "${target}.md";
          path = pkgs.writeText "agent-instructions-${target}.md" (
            lib.optionalString (t.h1 != null) "# ${t.h1}\n\n" + compose t.fragments
          );
        }) resolved
      );
in
mkBundle
