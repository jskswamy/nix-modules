{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/fabric/config";
  cfg = config.tools.fabric;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.fabric = {
    enable = mkToolEnable lib "fabric";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.fabric-ai;
      description = ''
        Package providing fabric, installed when this tool is enabled.

        Set to null to configure fabric without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # Individually symlinked so fabric keeps managing the rest of its
    # pattern directory itself.
    home.file = {
      ".config/fabric/patterns/conventional_commit".source = src.file "patterns/conventional_commit";
      ".config/fabric/patterns/git_status_summary".source = src.file "patterns/git_status_summary";
      ".config/fabric/patterns/homework_commit".source = src.file "patterns/homework_commit";
      ".config/fabric/patterns/semantic_commit".source = src.file "patterns/semantic_commit";
    };
  };
}
