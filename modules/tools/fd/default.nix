{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.fd;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.fd = {
    enable = mkToolEnable lib "fd";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.fd;
      description = ''
        Package providing fd, installed when this tool is enabled.

        Set to null to configure fd without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
