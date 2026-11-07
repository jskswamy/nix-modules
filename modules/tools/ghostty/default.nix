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

  # Ghostty has no Merino built in; install it as user themes.
  merinoTheme = p:
    lib.concatImapStrings (i: c: "palette = ${toString (i - 1)}=${c}\n") p.ansi
    + ''
      background = ${p.background}
      foreground = ${p.foreground}
      cursor-color = ${p.cursor}
      cursor-text = ${p.cursorText}
      selection-background = ${p.selectionBackground}
      selection-foreground = ${p.selectionForeground}
    '';
  merino = import ../../theme/merino.nix;
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

      # Included by config/ghostty/config via `config-file = ?~/.config/ghostty/theme.conf`,
      # so the rest of that file stays a plain instant-edit symlink.
      ".config/ghostty/theme.conf".text = "theme = light:${variantTitle} Light,dark:${variantTitle} Dark\n";
      ".config/ghostty/themes/Merino Dark".text = merinoTheme merino.dark;
      ".config/ghostty/themes/Merino Light".text = merinoTheme merino.light;

      ".local/bin/ghostty-terminfo" = {
        source = ./scripts/ghostty-terminfo;
        executable = true;
      };
    };
  };
}
