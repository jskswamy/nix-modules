{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/hunk/config";
  cfg = config.tools.hunk;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.hunk = {
    enable = mkToolEnable lib "hunk";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "hunk";
      description = ''
        Package providing hunk, installed when this tool is enabled.

        Set to null to configure hunk without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # hunk — diff review TUI wrapped by herdr-hunk-diff
    home.file.".config/hunk/config.toml".source =
      src.file "config.toml";

    # hunk is wired into git and lazygit from here, not the other way
    # round: neither host imports it, so without hunk git keeps its own
    # default pager and lazygit simply has no review keys.
    programs.git.settings.core.pager = "hunk pager";

    programs.lazygit.settings.customCommands = [
      {
        key = "H";
        context = "commits, subCommits, reflogCommits";
        description = "Review commit with hunk";
        command = "hunk show {{.SelectedCommit.Sha}}";
        output = "terminal";
      }
      {
        key = "H";
        context = "localBranches";
        description = "Review branch tip with hunk";
        command = "hunk show {{.SelectedLocalBranch.Name}}";
        output = "terminal";
      }
    ];
  };
}
