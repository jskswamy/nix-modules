# Terminal emulators and multiplexers: alacritty, ghostty, tmux, tmuxp.
{self}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../lib) mkSource;
  src = mkSource config self;

  # Files that were never instant-edit symlinks (scripts, static assets)
  # stay immutable store copies regardless of nixModules.sourceRoot.
  store = rel: self + "/${rel}";

  inherit (config.theme) variant;

  # Ghostty's built-in theme names are capitalized ("Gruvbox Light").
  variantTitle =
    lib.toUpper (builtins.substring 0 1 variant)
    + builtins.substring 1 1000 variant;

  ohMyTmux = pkgs.fetchFromGitHub {
    owner = "gpakosz";
    repo = ".tmux";
    rev = "af33f07134b76134acca9d01eacbdecca9c9cda6";
    sha256 = "sha256-nXm664l84YSwZeRM4Hsweqgz+OlpyfwXcgEdyNGhaGA=";
  };
  alacrittyTheme = pkgs.fetchFromGitHub {
    owner = "alacritty";
    repo = "alacritty-theme";
    rev = "2749b407b597790e6f08b218c2bc2acdf66210a0";
    sha256 = "sha256-F8ye16jhfldsyxcOqxVS0PNecVcQcAPnEahDKS4PGwE=";
  };
in {
  imports = [
    ../_common
    ../theme
  ];

  programs = {
    alacritty = {
      enable = lib.mkDefault true;
      settings = {
        cursor.style = lib.mkDefault "Block";

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
          option_as_alt = lib.mkDefault "Both";
          resize_increments = lib.mkDefault true; # Resize by character grid for performance
        };

        font = {
          normal = {
            family = lib.mkDefault "FiraCode Nerd Font Mono";
            style = lib.mkDefault "Regular";
          };
          size = lib.mkMerge [
            (lib.mkIf pkgs.stdenv.hostPlatform.isLinux 10)
            (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin 14)
          ];
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

    # tmux is configured entirely through oh-my-tmux plus conf.local below,
    # not through home-manager's own tmux module.
    tmux.enable = lib.mkDefault false;
  };

  home.file = {
    ".config/ghostty/config".source = src "modules/terminal/config/ghostty/config";

    # Included by config/ghostty/config via `config-file = ?theme.conf`, so
    # the rest of that file stays a plain instant-edit symlink.
    ".config/ghostty/theme.conf".text = "theme = light:${variantTitle} Light,dark:${variantTitle} Dark\n";

    ".tmux.conf.local".source = src "modules/terminal/config/tmux/conf.local";
    ".config/tmuxp".source = src "modules/terminal/config/tmuxp";

    ".local/bin/ghostty-terminfo" = {
      source = store "modules/terminal/scripts/ghostty-terminfo";
      executable = true;
    };

    # External fetches — upstream trees, not this repo's content.
    ".tmux.conf".source = "${ohMyTmux}/.tmux.conf";
    ".config/alacritty/themes" = {
      source = "${alacrittyTheme}/themes";
      recursive = true;
    };
  };
}
