{ pkgs, core }:
let
  inherit (pkgs) lib;
  inherit (import ./util.nix { inherit pkgs; }) mkCheck;

  common = [
    ./fixtures/COMMON.md
    ./fixtures/TOOL.md
  ];

  rule = ./fixtures/RULE.md;

  resolved = core.resolveTargets {
    fragments = common;
    targets = {
      claude.enable = true;
      codex = {
        enable = true;
        fragments = [ ./fixtures/CODEX.md ];
      };
      opencode.enable = false;
      custom = {
        enable = true;
        dest = ".custom/RULES.md";
        inheritCommon = false;
        fragments = [ ./fixtures/CODEX.md ];
      };
    };
  };

  errorsFor =
    targets:
    core.checkTargets (
      core.resolveTargets {
        fragments = common;
        inherit targets;
      }
    );
  hasError = needle: targets: lib.any (lib.hasInfix needle) (errorsFor targets);

  bundle = core.mkBundle {
    inherit pkgs;
    fragments = common;
    targets = {
      claude.enable = true;
      codex = {
        enable = true;
        fragments = [ ./fixtures/CODEX.md ];
      };
      goose.enable = true;
    };
  };
in
{
  core-uses-builtin-dest = mkCheck "core-uses-builtin-dest" (
    resolved.claude.dest == ".claude/CLAUDE.md"
  );

  core-composes-common-fragments = mkCheck "core-composes-common-fragments" (
    core.compose resolved.claude.fragments == "# Common\n\n## Tool\n"
  );

  core-appends-target-fragments = mkCheck "core-appends-target-fragments" (
    core.compose resolved.codex.fragments == "# Common\n\n## Tool\n\n## Codex\n"
  );

  core-custom-target-without-common = mkCheck "core-custom-target-without-common" (
    resolved.custom == {
      dest = ".custom/RULES.md";
      fragments = [ ./fixtures/CODEX.md ];
    }
  );

  core-skips-disabled-targets = mkCheck "core-skips-disabled-targets" (!(resolved ? opencode));

  core-valid-targets-have-no-errors = mkCheck "core-valid-targets-have-no-errors" (
    core.checkTargets resolved == [ ]
  );

  core-rejects-missing-dest = mkCheck "core-rejects-missing-dest" (
    hasError "dest is not set" { unknown.enable = true; }
  );

  core-rejects-empty-target = mkCheck "core-rejects-empty-target" (
    hasError "no fragments" {
      claude = {
        enable = true;
        inheritCommon = false;
      };
    }
  );

  core-rejects-duplicate-dest = mkCheck "core-rejects-duplicate-dest" (
    hasError "same dest" {
      claude.enable = true;
      other = {
        enable = true;
        dest = ".claude/CLAUDE.md";
      };
    }
  );

  core-trims-front-matter-and-h1 = mkCheck "core-trims-front-matter-and-h1" (
    core.compose [
      {
        path = rule;
        trimFrontMatter = true;
        trimH1 = true;
      }
    ] == "## Rule body\n"
  );

  core-trims-front-matter-only = mkCheck "core-trims-front-matter-only" (
    core.compose [
      {
        path = rule;
        trimFrontMatter = true;
      }
    ] == "# Rule\n\n## Rule body\n"
  );

  core-trims-h1-after-front-matter = mkCheck "core-trims-h1-after-front-matter" (
    core.compose [
      {
        path = rule;
        trimH1 = true;
      }
    ] == "---\npaths: \"*.nix\"\n---\n\n## Rule body\n"
  );

  # 先頭が H2 なら何も消さない。
  core-trim-h1-keeps-other-headings = mkCheck "core-trim-h1-keeps-other-headings" (
    core.compose [
      {
        path = ./fixtures/TOOL.md;
        trimH1 = true;
      }
    ] == "## Tool\n"
  );

  # 断片の前後の空行を除き、断片の間は空行 1 つにそろえる。
  core-normalizes-blank-lines = mkCheck "core-normalizes-blank-lines" (
    core.compose [
      (builtins.toFile "padded.md" "\n  \n## Padded\n\n\n")
      (builtins.toFile "no-newline.md" "## No newline")
      (builtins.toFile "blank.md" " \n")
      ./fixtures/TOOL.md
    ] == "## Padded\n\n## No newline\n\n## Tool\n"
  );

  # 本文を一つのバンドル直下にまとめる。
  core-bundle-contains-files = pkgs.runCommand "agent-instructions-core-bundle-contains-files" { } ''
    grep -qx '## Tool' ${bundle}/claude.md
    grep -qx '## Codex' ${bundle}/codex.md
    test -f ${bundle}/goose.md
    touch $out
  '';
}
