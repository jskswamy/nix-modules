{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/ghostty/config";
  cfg = config.tools.ghostty;
  inherit (config.theme) variant;

  # Ghostty's built-in theme names are capitalized ("Gruvbox Light").
  variantTitle =
    lib.toUpper (builtins.substring 0 1 variant)
    + builtins.substring 1 1000 variant;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ghostty.enable = mkToolEnable lib "ghostty";

  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/ghostty/config".source = src.file "config";

      # Included by config/ghostty/config via `config-file = ?theme.conf`, so
      # the rest of that file stays a plain instant-edit symlink.
      ".config/ghostty/theme.conf".text = "theme = light:${variantTitle} Light,dark:${variantTitle} Dark\n";

      ".local/bin/ghostty-terminfo" = {
        source = ./scripts/ghostty-terminfo;
        executable = true;
      };
    };
  };
}
