{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/pet/config";
  cfg = config.tools.pet;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.pet = {
    enable = mkToolEnable lib "pet";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.pet;
      description = ''
        Package providing pet, installed when this tool is enabled.

        Set to null to configure pet without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file = {
      ".config/pet/config.toml".source = src.file "config.toml";
      ".config/pet/snippet.toml".source = src.file "snippet.toml";
    };
  };
}
