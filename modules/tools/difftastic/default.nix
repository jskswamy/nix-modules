{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.difftastic;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.difftastic = {
    enable = mkToolEnable lib "difftastic";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.difftastic;
      description = ''
        Package providing difftastic (the `difft` binary), installed when
        this tool is enabled.

        Set to null to configure difftastic without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # difftastic is wired into git from here, not the other way round.
    # Home-manager's programs.difftastic is not used because it rewrites
    # `git diff` itself, while today's setup only adds a difftool and a
    # log alias and leaves plain `git diff` alone.
    programs.git.settings = {
      alias = {
        dft = "difftool";
        dftlog = "-c diff.external=difft log -p --ext-diff";
      };
      diff.tool = "difftastic";
      difftool.difftastic.cmd = ''difft "$LOCAL" "$REMOTE"'';
    };
  };
}
