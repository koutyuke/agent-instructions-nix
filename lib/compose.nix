{ lib }:
let
  isBlank = line: builtins.match "[[:space:]]*" line != null;
  dropLeadingBlank =
    lines:
    if lines != [ ] && isBlank (lib.head lines) then dropLeadingBlank (lib.tail lines) else lines;
  bom = builtins.fromJSON ''"\ufeff"'';

  # Number of lines in a leading `---` front matter block, 0 when there is none.
  frontMatterLength =
    lines:
    let
      close = lib.lists.findFirstIndex (l: l == "---") null (lib.drop 1 lines);
    in
    if lines != [ ] && lib.head lines == "---" && close != null then close + 2 else 0;

  # Level of an ATX heading line, or null. Setext headings are not recognized.
  headingLevel =
    line:
    let
      m = builtins.match " {0,3}(#{1,6})([ \t].*)?" line;
    in
    if m == null then null else lib.stringLength (lib.head m);

  # Tags each line with `code` (inside a fenced code block, fences included) and
  # returns the fence still open at the end, or null.
  scanFences =
    lib.foldl'
      (
        s: line:
        let
          backtick = builtins.match " {0,3}(`{3,})[^`]*" line;
          tilde = builtins.match " {0,3}(~{3,}).*" line;
          open =
            if backtick != null then
              lib.head backtick
            else if tilde != null then
              lib.head tilde
            else
              null;
          close = builtins.match " {0,3}(`{3,}|~{3,})[ \t]*" line;
          closes =
            close != null
            && lib.hasPrefix (lib.substring 0 1 s.fence) (lib.head close)
            && lib.stringLength (lib.head close) >= lib.stringLength s.fence;
        in
        {
          fence =
            if s.fence == null then
              open
            else if closes then
              null
            else
              s.fence;
          lines = s.lines ++ [
            {
              inherit line;
              code = s.fence != null || open != null;
            }
          ];
        }
      )
      {
        fence = null;
        lines = [ ];
      };

  # A source is a path, or `{ path; headingStrategy ? "none"; }`. "demote"
  # moves every heading one level down and "drop" removes a leading H1. Front
  # matter is always removed, an unclosed code fence is closed at the end, and
  # blank lines are collapsed outside code blocks.
  readSource =
    source:
    let
      f = if lib.isStringLike source then { path = source; } else source;
      strategy = f.headingStrategy or "none";
      raw = map (lib.removeSuffix "\r") (
        lib.splitString "\n" (lib.removePrefix bom (builtins.readFile f.path))
      );
      scanned = scanFences (dropLeadingBlank (lib.drop (frontMatterLength raw) raw));
      isHeading = l: !l.code && headingLevel l.line != null;

      leadingH1 = scanned.lines != [ ] && headingLevel (lib.head scanned.lines).line == 1;
      dropH1 = strategy == "drop" && leadingH1;
      kept = if dropH1 then lib.tail scanned.lines else scanned.lines;
      nextHeading = lib.lists.findFirstIndex isHeading (lib.length kept) kept;
      hasPreface = dropH1 && lib.any (l: !isBlank l.line) (lib.take nextHeading kept);

      demote =
        l:
        if isHeading l then
          l
          // {
            line =
              let
                m = builtins.match "( {0,3})(#.*)" l.line;
              in
              "${lib.elemAt m 0}#${lib.elemAt m 1}";
          }
        else
          l;
      shifted = if strategy == "demote" then map demote kept else kept;
      tooDeep = strategy == "demote" && lib.any (l: isHeading l && headingLevel l.line == 6) kept;

      # Trailing blank lines go first so that a closing fence does not keep them.
      trimEnd = ls: if ls != [ ] && isBlank (lib.last ls).line then trimEnd (lib.init ls) else ls;
      closed =
        trimEnd shifted
        ++ lib.optional (scanned.fence != null) {
          line = scanned.fence;
          code = true;
        };
      isBlankText = l: !l.code && isBlank l.line;
      collapsed = lib.foldl' (
        acc: l:
        if isBlankText l then
          if acc == [ ] || isBlankText (lib.last acc) then acc else acc ++ [ (l // { line = ""; }) ]
        else
          acc ++ [ l ]
      ) [ ] closed;
    in
    assert lib.assertOneOf "headingStrategy" strategy [
      "none"
      "demote"
      "drop"
    ];
    {
      text = lib.concatStringsSep "\n" (dropLeadingBlank (map (l: l.line) collapsed));
      h1Count = lib.count (l: isHeading l && headingLevel l.line == 1) shifted;
      warnings = map (w: "${toString f.path}: ${w}") (
        lib.optional (
          scanned.fence != null
        ) "code fence is not closed; closed it at the end of the source."
        ++ lib.optional tooDeep "a heading goes deeper than H6 after demote; written as \"#######\"."
        ++ lib.optional hasPreface "content after the dropped H1 now continues the preceding section."
      );
    };

  # Composes `{ h1 ? null; sources; }` (a resolved target works as is). The H1
  # comes first, non-empty sources are separated by one blank line, and the
  # text ends with a newline.
  compose =
    {
      h1 ? null,
      sources,
      ...
    }:
    lib.concatMapStringsSep "\n" (s: s + "\n") (
      lib.optional (h1 != null) "# ${h1}"
      ++ lib.filter (s: s != "") (map (f: (readSource f).text) sources)
    );

  # Warning messages for resolved targets; empty when the content is clean.
  # Source warnings are reported once even when targets share the source.
  targetWarnings =
    resolved:
    lib.unique (
      lib.concatLists (
        lib.mapAttrsToList (
          name: t:
          let
            read = map readSource t.sources;
            h1Count = lib.count (x: x != null) [ t.h1 ] + lib.foldl' (n: r: n + r.h1Count) 0 read;
          in
          lib.concatMap (r: r.warnings) read
          ++
            lib.optional (h1Count > 1)
              "targets.${name}: the output has multiple H1 headings; set headingStrategy = \"demote\" or \"drop\" on sources, or disable insertH1."
        ) resolved
      )
    );
in
{
  inherit compose targetWarnings;
}
