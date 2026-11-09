# Alacritty, including the upstream theme collection its settings import.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.alacritty;
  inherit (config.theme) variant;
  t = config.terminal;
  # Alacritty looks up styles by name, so a style without a real face in
  # the family must map to Regular; the shared face policy (modules/terminal)
  # already knows which faces the family ships.
  faceStyle = on: style:
    if on
    then style
    else "Regular";

  alacrittyTheme = pkgs.fetchFromGitHub {
    owner = "alacritty";
    repo = "alacritty-theme";
    rev = "2749b407b597790e6f08b218c2bc2acdf66210a0";
    sha256 = "sha256-F8ye16jhfldsyxcOqxVS0PNecVcQcAPnEahDKS4PGwE=";
  };

  # Merino isn't in alacritty-theme; generate it into the same themes dir.
  names = ["black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"];
  merinoTheme = p: let
    half = off: lib.listToAttrs (lib.imap0 (i: n: lib.nameValuePair n (builtins.elemAt p.ansi (i + off))) names);
  in
    (pkgs.formats.toml {}).generate "merino.toml" {
      colors = {
        primary = {inherit (p) background foreground;};
        cursor = {
          cursor = p.cursor;
          text = p.cursorText;
        };
        selection = {
          background = p.selectionBackground;
          text = p.selectionForeground;
        };
        normal = half 0;
        bright = half 8;
      };
    };
  merino = import ../../theme/merino.nix;
in {
  imports = [
    ../../_common
    ../../theme
    ../../terminal
  ];

  options.tools.alacritty.enable = mkToolEnable lib "alacritty";

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = lib.mkDefault true;
      settings = {
        cursor.style = {
          shape = lib.mkDefault (lib.toSentenceCase t.cursor.style);
          blinking = lib.mkDefault (
            if t.cursor.blink
            then "On"
            else "Never"
          );
        };

        selection.save_to_clipboard = lib.mkDefault t.copyOnSelect;

        scrolling = {
          history = lib.mkDefault 500; # Extremely aggressive for performance (was 1000)
          multiplier = lib.mkDefault 1; # Reduce scroll sensitivity for smoother experience
        };

        window = {
          opacity = lib.mkDefault 1.0;
          padding = {
            x = lib.mkDefault 24;
            y = lib.mkDefault 24;
          };
          dynamic_padding = lib.mkDefault false; # Static padding for better performance
          decorations = lib.mkDefault "None"; # Remove decorations for fastest rendering
          blur = lib.mkDefault false; # Disable blur for performance
          # Make Option key send Alt sequences on macOS
          option_as_alt = lib.mkDefault (
            if t.optionAsAlt
            then "Both"
            else "None"
          );
          resize_increments = lib.mkDefault true; # Resize by character grid for performance
        };

        # Font from the shared terminal options. Alacritty is not libghostty
        # and has no ligatures; its spacing is in whole pixels, not percent.
        font = lib.mapAttrsRecursive (_: lib.mkDefault) {
          normal = {
            inherit (t.font) family;
            style = "Regular";
          };
          bold.style = faceStyle t.face.bold "Bold";
          italic.style = faceStyle t.face.italic "Italic";
          bold_italic.style =
            faceStyle (t.face.bold && t.face.italic) "Bold Italic";
          # Linux keeps its own smaller size.
          size =
            if pkgs.stdenv.hostPlatform.isDarwin
            then t.font.size
            else 10;
          # shortcut: point size stands in for cell size, so pixels are approximate; tune here if Alacritty looks off next to Ghostty.
          offset = {
            x = builtins.floor (t.font.size * 0.6 * t.cell.widthPercent / 100.0 + 0.5);
            y = builtins.floor (t.font.size * t.cell.heightPercent / 100.0 + 0.5);
          };
        };

        general = {
          live_config_reload = lib.mkDefault true;
          # Derived from theme.variant rather than hardcoded, so the
          # colorscheme follows the same switch as every other tool.
          import = lib.mkDefault [
            "~/.config/alacritty/themes/${variant}_dark.toml"
          ];
        };

        keyboard.bindings = [
          # Shift+Enter sends ESC+CR for Claude Code multiline support.
          # fromJSON decodes to the actual ESC (0x1B) + CR (0x0D) control
          # bytes. Embedding those bytes literally in this file instead would
          # make the TOML generator emit a single-quoted literal string, which
          # Alacritty sends verbatim rather than interpreting.
          {
            key = "Return";
            mods = "Shift";
            chars = builtins.fromJSON ''"\u001b\r"'';
          }
        ];

        # Performance and debug optimizations
        debug = {
          # GPU acceleration (replaces old renderer.backend)
          renderer = lib.mkDefault "glsl3"; # Force modern OpenGL for best performance

          # Performance optimizations
          render_timer = lib.mkDefault false; # Disable debug render timer
          print_events = lib.mkDefault false; # Disable event logging
          log_level = lib.mkDefault "off"; # Disable all logging for performance (lowercase)
        };

        # Environment optimizations
        env = {
          TERM = lib.mkDefault "alacritty";
          ALACRITTY_LOG = lib.mkDefault "/dev/null"; # Suppress all logging
        };
      };
    };

    home.file.".config/alacritty/themes" = {
      source = "${alacrittyTheme}/themes";
      recursive = true;
    };
    home.file.".config/alacritty/themes/merino_dark.toml".source = merinoTheme merino.dark;
    home.file.".config/alacritty/themes/merino_light.toml".source = merinoTheme merino.light;
  };
}
