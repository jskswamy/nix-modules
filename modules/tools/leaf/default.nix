{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/leaf/config";
  cfg = config.tools.leaf;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.leaf = {
    enable = mkToolEnable lib "leaf";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "leaf";
      description = ''
        Package providing leaf, installed when this tool is enabled.

        Set to null to configure leaf without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;
      file = {
        ".config/leaf/config.toml".source = src.file "config.toml";
        ".config/leaf/themes/merino-dark.toml".source = src.file "themes/merino-dark.toml";
        ".config/leaf/themes/merino-light.toml".source = src.file "themes/merino-light.toml";
      };
    };
  };
}
