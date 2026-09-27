{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.ripgrep;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ripgrep = {
    enable = mkToolEnable lib "ripgrep";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.ripgrep;
      description = ''
        Package providing ripgrep, installed when this tool is enabled.

        Set to null to configure ripgrep without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
