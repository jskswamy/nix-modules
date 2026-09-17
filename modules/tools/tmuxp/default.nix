{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/tmuxp/config";
  cfg = config.tools.tmuxp;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.tmuxp = {
    enable = mkToolEnable lib "tmuxp";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.tmuxp;
      description = ''
        Package providing tmuxp, installed when this tool is enabled.

        Set to null to configure tmuxp without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file.".config/tmuxp".source = src.dir;
  };
}
