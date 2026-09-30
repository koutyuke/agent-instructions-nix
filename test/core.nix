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

  textOf = fragments: core.compose { inherit fragments; };
  # Composed text and targetWarnings for the same fragments.
  composeWith = t: {
    text = core.compose t;
    warnings = core.targetWarnings {
      test = {
        h1 = null;
      }
      // t;
    };
  };
  bom = builtins.fromJSON ''"\ufeff"'';

  h1For =
    args:
    lib.mapAttrs (_: t: t.h1) (
      core.resolveTargets (
        {
          fragments = common;
        }
        // args
      )
    );

  bundle = core.mkBundle {
    inherit pkgs;
    fragments = [
      {
        path = ./fixtures/COMMON.md;
        headingStrategy = "demote";
      }
      ./fixtures/TOOL.md
    ];
    insertH1.enable = true;
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
    core.compose resolved.claude == "# Common\n\n## Tool\n"
  );

  core-appends-target-fragments = mkCheck "core-appends-target-fragments" (
    core.compose resolved.codex == "# Common\n\n## Tool\n\n## Codex\n"
  );

  core-custom-target-without-common = mkCheck "core-custom-target-without-common" (
    resolved.custom == {
      dest = ".custom/RULES.md";
      fragments = [ ./fixtures/CODEX.md ];
      h1 = null;
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

  core-strips-front-matter = mkCheck "core-strips-front-matter" (
    textOf [ rule ] == "# Rule\n\n## Rule body\n"
  );

  core-demotes-headings = mkCheck "core-demotes-headings" (
    textOf [
      {
        path = rule;
        headingStrategy = "demote";
      }
    ] == "## Rule\n\n### Rule body\n"
  );

  # demote shifts headings even without an H1, but leaves code fences unchanged.
  core-demote-skips-code-fences = mkCheck "core-demote-skips-code-fences" (
    textOf [
      ./fixtures/TOOL.md
      {
        path = builtins.toFile "fenced.md" "## A\n\n~~~sh\n# comment\n~~~\n";
        headingStrategy = "demote";
      }
    ] == "## Tool\n\n### A\n\n~~~sh\n# comment\n~~~\n"
  );

  core-demote-warns-beyond-h6 =
    let
      c = composeWith {
        fragments = [
          {
            path = builtins.toFile "h6.md" "###### Six\n";
            headingStrategy = "demote";
          }
        ];
      };
    in
    mkCheck "core-demote-warns-beyond-h6" (
      c.text == "####### Six\n" && lib.any (lib.hasInfix "H6") c.warnings
    );

  core-drops-leading-h1 =
    let
      c = composeWith {
        fragments = [
          {
            path = rule;
            headingStrategy = "drop";
          }
          {
            path = ./fixtures/TOOL.md;
            headingStrategy = "drop";
          }
        ];
      };
    in
    mkCheck "core-drops-leading-h1" (c.text == "## Rule body\n\n## Tool\n" && c.warnings == [ ]);

  # Keep text after the H1 and warn that it may merge with the preceding section.
  core-drop-warns-on-preface =
    let
      c = composeWith {
        fragments = [
          {
            path = builtins.toFile "preface.md" "# Title\n\ncontents\n\n## H2\n";
            headingStrategy = "drop";
          }
        ];
      };
    in
    mkCheck "core-drop-warns-on-preface" (
      c.text == "contents\n\n## H2\n" && lib.any (lib.hasInfix "dropped H1") c.warnings
    );

  core-warns-multiple-h1 =
    let
      c = composeWith {
        h1 = "CLAUDE.md";
        fragments = [ ./fixtures/COMMON.md ];
      };
    in
    mkCheck "core-warns-multiple-h1" (
      c.text == "# CLAUDE.md\n\n# Common\n"
      && lib.any (lib.hasInfix "multiple H1") c.warnings
      && core.targetWarnings resolved == [ ]
    );

  # Close an unclosed fence with the same marker and length, leaving headings inside unchanged.
  core-closes-unclosed-fence =
    let
      c = composeWith {
        fragments = [
          {
            path = builtins.toFile "unclosed.md" "# A\n\n````md\n```\n# x\n";
            headingStrategy = "demote";
          }
          ./fixtures/TOOL.md
        ];
      };
    in
    mkCheck "core-closes-unclosed-fence" (
      c.text == "## A\n\n````md\n```\n# x\n````\n\n## Tool\n"
      && lib.any (lib.hasInfix "not closed") c.warnings
    );

  # Report shared fragment warnings once, but duplicate H1 warnings per target.
  core-target-warnings-are-deduplicated =
    let
      warnings = core.targetWarnings (
        core.resolveTargets {
          fragments = [
            (builtins.toFile "unclosed-shared.md" "```\n")
            ./fixtures/COMMON.md
          ];
          insertH1.enable = true;
          targets = {
            claude.enable = true;
            codex.enable = true;
          };
        }
      );
    in
    mkCheck "core-target-warnings-are-deduplicated" (
      lib.count (lib.hasInfix "not closed") warnings == 1
      && lib.any (lib.hasPrefix "targets.claude: ") warnings
      && lib.any (lib.hasPrefix "targets.codex: ") warnings
    );

  core-rejects-unknown-heading-strategy = mkCheck "core-rejects-unknown-heading-strategy" (
    !(builtins.tryEval (textOf [
      {
        path = ./fixtures/TOOL.md;
        headingStrategy = "remove";
      }
    ])).success
  );

  core-collapses-blank-lines-outside-code = mkCheck "core-collapses-blank-lines-outside-code" (
    textOf [ (builtins.toFile "blank-lines.md" "## A\n\n\n\ntext\n\n```\na\n\n\nb\n```\n") ]
    == "## A\n\ntext\n\n```\na\n\n\nb\n```\n"
  );

  core-normalizes-crlf-and-bom = mkCheck "core-normalizes-crlf-and-bom" (
    textOf [
      (builtins.toFile "crlf.md" "${bom}---\r\nx: 1\r\n---\r\n## A\r\ntext\r\n")
    ] == "## A\ntext\n"
  );

  core-insert-h1 = mkCheck "core-insert-h1" (
    h1For {
      insertH1.enable = true;
      targets = {
        claude.enable = true;
        goose.enable = true;
        codex = {
          enable = true;
          insertH1 = {
            enable = true;
            text = "Codex rules";
          };
        };
        opencode = {
          enable = true;
          insertH1.enable = false;
        };
      };
    } == {
      claude = "CLAUDE.md";
      goose = ".goosehints";
      codex = "Codex rules";
      opencode = null;
    }
  );

  core-insert-h1-uses-common-text = mkCheck "core-insert-h1-uses-common-text" (
    h1For {
      insertH1 = {
        enable = true;
        text = "Rules";
      };
      targets.claude.enable = true;
    } == {
      claude = "Rules";
    }
  );

  # Trim blank lines around fragments and separate them with one blank line.
  core-normalizes-blank-lines = mkCheck "core-normalizes-blank-lines" (
    textOf [
      (builtins.toFile "padded.md" "\n  \n## Padded\n\n\n")
      (builtins.toFile "no-newline.md" "## No newline")
      (builtins.toFile "blank.md" " \n")
      ./fixtures/TOOL.md
    ] == "## Padded\n\n## No newline\n\n## Tool\n"
  );

  # Collect the composed text directly in one bundle.
  core-bundle-contains-files = pkgs.runCommand "agent-instructions-core-bundle-contains-files" { } ''
    test "$(head -n 1 ${bundle}/claude.md)" = '# CLAUDE.md'
    test -z "$(sed -n 2p ${bundle}/claude.md)"
    grep -qx '## Common' ${bundle}/claude.md
    grep -qx '## Tool' ${bundle}/claude.md
    grep -qx '## Codex' ${bundle}/codex.md
    test -f ${bundle}/goose.md
    touch $out
  '';
}
