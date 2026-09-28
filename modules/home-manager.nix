# Home Manager adapter: options map 1:1 to the core API in lib/, and the bundle
# is linked into $HOME with home.file.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  core = import ../lib { inherit lib; };
  hmContextOptions = import ./hm-context-options.nix;

  cfg = config.programs.agent-instructions;

  args = {
    inherit (cfg) fragments;
    targets = lib.mapAttrs (_: t: removeAttrs t [ "_module" ]) cfg.targets;
  };
  resolved = core.resolveTargets args;
  errors = core.checkTargets resolved;
  bundle = core.mkBundle (args // { inherit pkgs; });

  targetModule =
    { name, ... }:
    {
      options = {
        enable = lib.mkEnableOption "global instructions for the ${name} target";

        dest = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = ".claude/CLAUDE.md";
          description = "Destination path relative to the home directory. Built-in targets default to their known path.";
        };

        fragments = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = "Fragments appended after the common fragments for this target.";
        };

        inheritCommon = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to prepend {option}`programs.agent-instructions.fragments`.";
        };
      };
    };
in
{
  options.programs.agent-instructions = {
    enable = lib.mkEnableOption "declarative global instructions for AI coding agents";

    fragments = mkOption {
      type = types.listOf types.path;
      default = [ ];
      example = lib.literalExpression "[ ./instructions/COMMON.md ]";
      description = "Markdown fragments shared by every target, concatenated in order.";
    };

    targets = mkOption {
      type = types.attrsOf (types.submodule targetModule);
      default = { };
      description = ''
        Agents to write instructions for. Built-in targets only need `enable = true`;
        any other name works as a custom target when `dest` is set.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      map (message: {
        assertion = false;
        message = "programs.agent-instructions: ${message}";
      }) errors
      # Check that there is no overlap with programs.{provider}.context on the Home Manager side
      ++ lib.mapAttrsToList (name: path: {
        assertion = !(resolved ? ${name}) || lib.attrByPath path "" config == "";
        message = "programs.agent-instructions.targets.${name} writes the same file as `${lib.concatStringsSep "." path}`; set only one of them.";
      }) hmContextOptions;

    # Skipped on errors so the assertions above are reported instead of a throw.
    home.file = lib.mkIf (errors == [ ]) (
      lib.mapAttrs' (_: t: lib.nameValuePair t.dest { source = "${bundle}/${t.dest}"; }) resolved
    );
  };
}
