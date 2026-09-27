{ pkgs, core }:
let
  inherit (pkgs) lib;
  inherit (import ./util.nix { inherit pkgs; }) mkCheck;

  common = [
    ./fixtures/COMMON.md
    ./fixtures/TOOL.md
  ];

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

  # The bundle mirrors $HOME, including dot-directories and dotfiles.
  core-bundle-contains-files = pkgs.runCommand "agent-instructions-core-bundle-contains-files" { } ''
    grep -qx '## Tool' ${bundle}/.claude/CLAUDE.md
    test -f ${bundle}/.config/goose/.goosehints
    touch $out
  '';
}
