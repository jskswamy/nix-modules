{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.git-absorb;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.git-absorb = {
    enable = mkToolEnable lib "git-absorb";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.git-absorb;
      description = ''
        Package providing git-absorb, installed when this tool is enabled.

        Set to null to configure git-absorb without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # git-absorb defaults to searching only 10 commits back; raise the stack
    # depth so feature branches with more granular commits work out of the box.
    programs.git.settings.absorb.maxStack = lib.mkDefault 50;
  };
}
