{
  pkgs,
  home-manager,
  module,
}:
let
  inherit (pkgs) lib;
  inherit (import ./util.nix { inherit pkgs; }) mkCheck;

  # homeManagerConfiguration throws on failed assertions, so evaluate the raw
  # module set the same way to inspect assertion messages.
  hmLib = import "${home-manager}/modules/lib/stdlib-extended.nix" lib;
  hmModules = import "${home-manager}/modules/modules.nix" {
    inherit pkgs;
    lib = hmLib;
  };

  evalRaw =
    config:
    hmLib.evalModules {
      modules = hmModules ++ [
        module
        {
          home = {
            username = "test";
            homeDirectory = "/home/test";
            stateVersion = "25.11";
          };
        }
        config
      ];
      class = "homeManager";
      specialArgs.modulesPath = "${home-manager}/modules";
    };

  eval = config: (evalRaw config).config;

  defaultTargets = import ../lib/targets.nix;
  hmContextOptions = import ../modules/hm-context-options.nix;

  failedAssertions =
    config: map (a: a.message) (lib.filter (a: !a.assertion) (eval config).assertions);

  hasFailure = needle: config: lib.any (lib.hasInfix needle) (failedAssertions config);

  withTargets = targets: {
    programs.agent-instructions = {
      enable = true;
      sources = [
        ./fixtures/COMMON.md
        ./fixtures/TOOL.md
      ];
      inherit targets;
    };
  };

  composed = eval (withTargets {
    claude.enable = true;
    codex = {
      enable = true;
      sources = [ ./fixtures/CODEX.md ];
    };
  });
in
{
  hm-valid-config-passes-assertions = mkCheck "hm-valid-config-passes-assertions" (
    lib.all (a: a.assertion) composed.assertions
  );

  hm-links-bundle-files = pkgs.runCommand "agent-instructions-hm-links-bundle-files" { } ''
    grep -qx '## Tool' ${composed.home.file.".claude/CLAUDE.md".source}
    grep -qx '## Codex' ${composed.home.file.".codex/AGENTS.md".source}
    test "$(basename ${composed.home.file.".claude/CLAUDE.md".source})" = claude.md
    test "$(basename ${composed.home.file.".codex/AGENTS.md".source})" = codex.md
    test "$(dirname ${composed.home.file.".claude/CLAUDE.md".source})" = \
      "$(dirname ${composed.home.file.".codex/AGENTS.md".source})"
    touch $out
  '';

  hm-applies-heading-strategy-and-inserts-h1 =
    let
      config = eval {
        programs.agent-instructions = {
          enable = true;
          insertH1.enable = true;
          sources = [
            {
              path = ./fixtures/RULE.md;
              headingStrategy = "drop";
            }
          ];
          targets.claude.enable = true;
        };
      };
    in
    pkgs.runCommand "agent-instructions-hm-applies-heading-strategy-and-inserts-h1" { } ''
      test "$(cat ${
        config.home.file.".claude/CLAUDE.md".source
      })" = "$(printf '# CLAUDE.md\n\n## Rule body')"
      touch $out
    '';

  hm-dest-is-overridable = mkCheck "hm-dest-is-overridable" (
    (eval (withTargets {
      claude = {
        enable = true;
        dest = ".config/claude/CLAUDE.md";
      };
    })).home.file
      ? ".config/claude/CLAUDE.md"
  );

  hm-all-builtin-targets-are-written = mkCheck "hm-all-builtin-targets-are-written" (
    let
      config = eval (withTargets (lib.mapAttrs (_: _: { enable = true; }) defaultTargets));
    in
    lib.all (a: a.assertion) config.assertions
    && lib.all (t: config.home.file ? ${t.dest}) (lib.attrValues defaultTargets)
  );

  hm-reports-core-errors = mkCheck "hm-reports-core-errors" (
    hasFailure "dest is not set" (withTargets {
      unknown.enable = true;
    })
  );

  hm-rejects-context-conflict = mkCheck "hm-rejects-context-conflict" (
    hasFailure "programs.claude-code.context" (
      lib.recursiveUpdate (withTargets { claude.enable = true; }) {
        programs.claude-code.context = "other";
      }
    )
  );

  # Guards against typos: attrByPath would silently skip a misspelled option.
  hm-context-options-exist = mkCheck "hm-context-options-exist" (
    let
      inherit (evalRaw { }) options;
    in
    lib.all (path: lib.hasAttrByPath path options) (lib.attrValues hmContextOptions)
  );
}
