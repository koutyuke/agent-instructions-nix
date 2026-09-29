{ lib, defaultTargets }:
let
  # Enabled targets as `{ <name> = { dest; fragments; h1; }; }`, with built-in
  # dests filled in and common fragments prepended unless inheritCommon = false.
  # `dest` is null when neither the target nor a built-in provides one.
  # `h1` is the heading text to insert, or null; a target's `insertH1` replaces
  # the common one, and a null `text` falls back to the dest's file name.
  resolveTargets =
    {
      fragments ? [ ],
      insertH1 ? { },
      targets ? { },
    }:
    lib.mapAttrs (
      name: t:
      let
        dest = if t.dest or null != null then t.dest else defaultTargets.${name}.dest or null;
        h1 = if t.insertH1 or null != null then t.insertH1 else insertH1;
      in
      {
        inherit dest;
        fragments = lib.optionals (t.inheritCommon or true) fragments ++ t.fragments or [ ];
        h1 =
          if !(h1.enable or false) then
            null
          else if h1.text or null != null then
            h1.text
          else if dest != null then
            baseNameOf dest
          else
            null;
      }
    ) (lib.filterAttrs (_: t: t.enable or false) targets);

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
in
{
  inherit resolveTargets checkTargets;
}
