{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  fishSrc = mkSource config ./fish "modules/tools/any-nix-shell/fish";
  cfg = config.tools.any-nix-shell;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.any-nix-shell = {
    enable = mkToolEnable lib "any-nix-shell";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.any-nix-shell;
      description = ''
        Package providing any-nix-shell, installed when this tool is enabled.

        Set to null to configure any-nix-shell without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
    home.file.".config/fish/conf.d/any-nix-shell.fish".source = fishSrc.file "any-nix-shell.fish";
  };
}
