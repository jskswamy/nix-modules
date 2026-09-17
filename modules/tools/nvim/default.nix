# Neovim (LazyVim). The whole config directory is symlinked, so edits take
# effect without a rebuild.
{
  config,
  lib,
  pkgs,
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

  options.tools.nvim = {
    enable = mkToolEnable lib "nvim";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.neovim;
      description = ''
        Package providing nvim, installed when this tool is enabled.

        Set to null to configure nvim without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file.".config/nvim".source = src.dir;
  };
}
