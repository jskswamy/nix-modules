{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.ast-grep;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ast-grep = {
    enable = mkToolEnable lib "ast-grep";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.ast-grep;
      description = ''
        Package providing ast-grep (the `ast-grep` and `sg` binaries), installed
        when this tool is enabled.

        Set to null to configure ast-grep without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
  };
}
