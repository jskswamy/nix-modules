{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.delta;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.delta = {
    enable = mkToolEnable lib "delta";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.delta;
      description = ''
        Package providing delta, installed when this tool is enabled.

        Set to null to configure delta without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # delta is wired into git and lazygit from here, not the other way
    # round: neither host imports it, so enabling delta is what turns
    # these lines on. Home-manager's programs.delta is not used because
    # its git integration replaces the pagers for blame, diff, log and
    # show, and without it the binary is wrapped in a --config file; both
    # move where these settings live.
    programs.git.settings = {
      # hunk needs a real TTY to render (falls back to plain passthrough
      # otherwise, confirmed by testing), so the non-interactive filter
      # paths below stay on delta.
      interactive.diffFilter = "delta --color-only";
      delta = {
        syntax-theme = "ansi";
        side-by-side = false;
        line-numbers = true;
        navigate = true;
        hyperlinks = true;
        line-numbers-minus-style = "red";
        line-numbers-plus-style = "green";
        # plus-style/minus-style default to "syntax auto"/"normal auto",
        # which resolves to delta's own hardcoded RGB backgrounds instead
        # of following the terminal's ANSI theme (confirmed by testing —
        # showed up as a fixed dark red/green regardless of gruvbox
        # light/dark). Tried "syntax <ansi-color>" (theme-relative
        # background, syntax-highlighted foreground) but that composites
        # two independently-chosen colors — some syntax token colors
        # ended up low-contrast against the background, confirmed by
        # testing both as a full-line wash and as word-level emphasis.
        #
        # Settled on a fixed foreground+background PAIR instead (soft
        # pastel pink/green, approximated from Claude Code's own diff
        # rendering, which the user specifically liked) — guaranteed
        # contrast by construction since both colors are chosen together,
        # rather than composed from two unrelated sources. Trade-off:
        # fixed hex, so it won't adapt if the terminal theme changes to
        # something these pastels clash with.
        minus-style = ''"#9d0006" "#f2d5d5"'';
        plus-style = ''"#79740e" "#e3ecd0"'';
        minus-emph-style = ''"#9d0006" "#f2d5d5" bold'';
        plus-emph-style = ''"#79740e" "#e3ecd0" bold'';
      };
    };

    programs.lazygit.settings.git.diffRenderers = [
      {
        colorArg = "always";
        command = "delta --paging=never";
      }
    ];
  };
}
