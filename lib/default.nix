# Core API. Depends only on nixpkgs `lib` (and `pkgs` for mkBundle), so any
# module system or script can build on it; see modules/ for adapters.
{ lib }:
let
  defaultTargets = import ./targets.nix;

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

  isBlank = line: builtins.match "[[:space:]]*" line != null;
  dropLeadingBlank =
    lines:
    if lines != [ ] && isBlank (lib.head lines) then dropLeadingBlank (lib.tail lines) else lines;
  trimBlank = lines: lib.reverseList (dropLeadingBlank (lib.reverseList (dropLeadingBlank lines)));

  # Number of lines in a leading `---` front matter block, 0 when there is none.
  frontMatterLength =
    lines:
    let
      close = lib.lists.findFirstIndex (l: l == "---") null (lib.drop 1 lines);
    in
    if lines != [ ] && lib.head lines == "---" && close != null then close + 2 else 0;

  # A fragment is a path, or `{ path; trimFrontMatter ? false; trimH1 ? false; }`.
  # Leading and trailing blank lines are always removed. trimH1 only removes an
  # ATX H1 that comes first after the front matter.
  readFragment =
    fragment:
    let
      f = if lib.isStringLike fragment then { path = fragment; } else fragment;
      lines = lib.splitString "\n" (builtins.readFile f.path);
      fmLength = frontMatterLength lines;
      body = lib.drop fmLength lines;
      firstBody = dropLeadingBlank body;
      hasH1 = firstBody != [ ] && builtins.match "#([ \t].*)?" (lib.head firstBody) != null;
    in
    lib.concatStringsSep "\n" (
      trimBlank (
        lib.optionals (!(f.trimFrontMatter or false)) (lib.take fmLength lines)
        ++ (if f.trimH1 or false && hasH1 then lib.tail firstBody else body)
      )
    );

  # Fragments are separated by one blank line and the result ends with a newline.
  compose =
    fragments:
    lib.concatMapStringsSep "\n" (s: s + "\n") (lib.filter (s: s != "") (map readFragment fragments));

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
{
  inherit
    defaultTargets
    resolveTargets
    checkTargets
    compose
    mkBundle
    ;
}
