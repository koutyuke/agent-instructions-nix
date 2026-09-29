{ lib }:
let
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
in
compose
