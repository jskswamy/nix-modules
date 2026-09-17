# Editors: neovim (LazyVim), vim, zed.
{self}: {
  config,
  pkgs,
  ...
}: let
  inherit (import ../../lib) mkSource;
  src = mkSource config self;
in {
  imports = [
    ../_common
    ../theme
  ];

  # Kept in its own file so the long extraConfig stays exactly as written.
  programs.vim = import ./vim.nix {inherit pkgs;};

  # Zed's settings.json is not shipped here: it pins an absolute path to a
  # binary under a specific user's home directory. A consumer provides its own.
  home.file = {
    ".config/nvim".source = src "modules/editor/config/nvim";
  };
}
