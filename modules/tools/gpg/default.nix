{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  fishSrc = mkSource config ./fish "modules/tools/gpg/fish";
  cfg = config.tools.gpg;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.gpg.enable = mkToolEnable lib "gpg";

  config = lib.mkIf cfg.enable {
    # Kept in its own file so the long settings block stays as written.
    programs.gpg = import ./gpg.nix {};

    home.file = {
      ".config/fish/conf.d/gpg.fish".source = fishSrc.file "gpg.fish";
      ".local/bin/gpg-sign-wrapper" = {
        source = ./scripts/gpg-sign-wrapper;
        executable = true;
      };
    };
  };
}
