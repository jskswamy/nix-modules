{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.vim;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.vim.enable = mkToolEnable lib "vim";

  config = lib.mkIf cfg.enable {
    # Kept in its own file so the long extraConfig stays exactly as written.
    programs.vim = import ./vim.nix {inherit pkgs;};
  };
}
