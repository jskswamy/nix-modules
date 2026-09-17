{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/tig/config";
  cfg = config.tools.tig;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.tig = {
    enable = mkToolEnable lib "tig";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.tig;
      description = ''
        Package providing tig, installed when this tool is enabled.

        Set to null to configure tig without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file.".config/tig/config".source = src.file "config";
  };
}
