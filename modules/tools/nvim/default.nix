# Neovim (LazyVim). The whole config directory is symlinked, so edits take
# effect without a rebuild.
{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/nvim/config";
  cfg = config.tools.nvim;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.nvim.enable = mkToolEnable lib "nvim";

  config = lib.mkIf cfg.enable {
    home.file.".config/nvim".source = src.dir;
  };
}
