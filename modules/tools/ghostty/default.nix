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

  options.tools.ghostty = {
    enable = mkToolEnable lib "ghostty";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      example = "pkgs.ghostty-bin";
      description = ''
        Package providing ghostty, installed when this tool is enabled.

        Defaults to null — this module configures ghostty but does not
        install it, because the usual macOS source is the `ghostty@tip`
        Homebrew cask and upstream publishes no stable Nix build of the
        macOS app. Ghostty's own flake builds the terminal on Linux only;
        on darwin it exposes just libghostty-vt.

        To install it with Nix instead, set this to `pkgs.ghostty` on
        Linux or `pkgs.ghostty-bin` on aarch64-darwin. Note that
        ghostty-bin tracks stable releases, so it is a downgrade from the
        nightly cask.
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
