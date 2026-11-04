{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/nexo/config";
  cfg = config.tools.nexo;
in {
  imports = [
    ../../_common
  ];

  options.tools.nexo = {
    enable = mkToolEnable lib "nexo";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "nexo";
      description = ''
        Package providing nexo, installed when this tool is enabled.

        Set to null to configure nexo without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;
      file.".config/nexo/config.toml".source = src.file "config.toml";
    };
  };
}
