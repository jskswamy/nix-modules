{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.gh-dash;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.gh-dash = {
    enable = mkToolEnable lib "gh-dash";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.gh-dash;
      description = ''
        Package providing gh-dash, installed when this tool is enabled.

        Set to null to configure gh-dash without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
