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

  options.tools.tmux.enable = mkToolEnable lib "tmux";

  config = lib.mkIf cfg.enable {
    programs.tmux.enable = lib.mkDefault false;

    home.file = {
      ".tmux.conf".source = "${ohMyTmux}/.tmux.conf";
      ".tmux.conf.local".source = src.file "conf.local";
    };
  };
}
