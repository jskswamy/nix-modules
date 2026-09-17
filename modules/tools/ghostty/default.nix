{
  config,
  lib,
  pkgs,
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

  options.tools.ghostty = {
    enable = mkToolEnable lib "ghostty";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
          Package providing ghostty, installed when this tool is enabled.

          Ghostty is not taken from nixpkgs here — on darwin it comes
        from the `ghostty` Homebrew cask. Point this at a package if you
        want Nix to install it.

        Set to null to configure ghostty without installing it — for a
          binary that comes from the system, Homebrew, or a language
          package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

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
