{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/nbdime/config";
  cfg = config.tools.nbdime;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.nbdime = {
    enable = mkToolEnable lib "nbdime";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
          Package providing nbdime, installed when this tool is enabled.

          nbdime is a Python tool, usually installed through uv or pip
        rather than nixpkgs.

        Set to null to configure nbdime without installing it — for a
          binary that comes from the system, Homebrew, or a language
          package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file.".config/nbdime/config.json".source =
      src.file "config.json";
  };
}
