# Core API. Depends only on nixpkgs `lib` (and `pkgs` for mkBundle), so any
# module system or script can build on it; see modules/ for adapters.
{ lib }:
let
  defaultTargets = import ./targets.nix;

  # Enabled targets as `{ <name> = { dest; fragments; }; }`, with built-in
  # dests filled in and common fragments prepended unless inheritCommon = false.
  # `dest` is null when neither the target nor a built-in provides one.
  resolveTargets =
    {
      fragments ? [ ],
      targets ? { },
    }:
    lib.mapAttrs (name: t: {
      dest = if t.dest or null != null then t.dest else defaultTargets.${name}.dest or null;
      fragments = lib.optionals (t.inheritCommon or true) fragments ++ t.fragments or [ ];
    }) (lib.filterAttrs (_: t: t.enable or false) targets);

  # Error messages for resolved targets; empty when they can be written.
  checkTargets =
    resolved:
    let
      dests = lib.filter (d: d != null) (lib.mapAttrsToList (_: t: t.dest) resolved);
    in
    lib.concatLists (
      lib.mapAttrsToList (
        name: t:
        lib.optional (t.dest == null) "targets.${name}: dest is not set."
        ++ lib.optional (t.fragments == [ ]) "targets.${name}: no fragments to write."
      ) resolved
    )
    ++ lib.optional (
      lib.unique dests != dests
    ) "multiple targets share the same dest (${lib.concatStringsSep ", " dests}).";

  compose = fragments: lib.concatMapStringsSep "\n" builtins.readFile fragments;

  # A store tree mirroring $HOME, e.g. $out/.claude/CLAUDE.md.
  mkBundle =
    {
      pkgs,
      fragments ? [ ],
      targets ? { },
      name ? "agent-instructions",
    }:
    let
      resolved = resolveTargets { inherit fragments targets; };
      errors = checkTargets resolved;
    in
    if errors != [ ] then
      throw "agent-instructions:\n${lib.concatMapStringsSep "\n" (e: "- ${e}") errors}"
    else
      pkgs.linkFarm name (
        lib.mapAttrsToList (target: t: {
          name = t.dest;
          path = pkgs.writeText "agent-instructions-${target}.md" (compose t.fragments);
        }) resolved
      );
in
{
  inherit
    defaultTargets
    resolveTargets
    checkTargets
    compose
    mkBundle
    ;
}
