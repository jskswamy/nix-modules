# tmux, configured through oh-my-tmux plus a local conf.local rather than
# home-manager's own tmux module.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/tmux/config";
  cfg = config.tools.tmux;

  ohMyTmux = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "af33f07134b76134acca9d01eacbdecca9c9cda6";
    sha256 = "sha256-nXm664l84YSwZeRM4Hsweqgz+OlpyfwXcgEdyNGhaGA=";
  };
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.tmux = {
    enable = mkToolEnable lib "tmux";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.tmux;
      description = ''
        Package providing tmux, installed when this tool is enabled.

        Set to null to configure tmux without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    programs.tmux.enable = lib.mkDefault false;

    home.file = {
      ".tmux.conf".source = "${ohMyTmux}/.tmux.conf";
      ".tmux.conf.local".source = src.file "conf.local";
    };
  };
}
