{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/herdr-app/config";
  cfg = config.tools.herdr-app;

  generateKeys = pkgs.writeScript "herdr-app-generate-keys" ''
    export PATH=${lib.makeBinPath [pkgs.python3]}:$PATH
    exec python3 ${./generate-keys.py} "$@"
  '';
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.herdr-app = {
    enable = mkToolEnable lib "herdr-app";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Package providing herdr-app, installed when this tool is enabled.

        Defaults to null — this module configures herdr-app but does not
        install it. The desktop app ships no Homebrew cask and no Nix
        package; the usual source is herdr's install script, which puts
        Herdr.app in /Applications and a herdr-app symlink in
        ~/.local/bin.
      '';
    };

    extraKeys = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
      default = {
        # terminal-section values are actions; raw bytes use "send:<text>"
        # (the vendored defaults encode alt-backspace as send:ESC+ctrl-w).
        # Nix string literals have no \u escape, so the bytes come from
        # fromJSON: this is Ghostty's ESC+DEL (delete-word). alt-left/
        # right already ship in the vendored defaults.
        terminal."alt-backspace" = "send:${builtins.fromJSON ''"\u001b\u007f"''}";
      };
      example = {
        global."ctrl-shift-t" = "terminal";
      };
      description = ''
        Desktop-only key bindings merged last over both the vendored
        herdr-app defaults and the keys translated from the herdr TUI's
        config.toml. Sections are 'global', 'terminal', 'layout:<name>'
        or 'mod:<name>'; values are commands, 'send:<text>' or
        'terminal' (unbind).

        Keys shared with the TUI (the ctrl+a prefix scheme) belong in
        the herdr TUI config, not here — that file is the source of
        truth and this option will be overridden by it wherever both
        name the same sequence.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file = {
      # herdr-app — desktop multiplexer client. Its terminal panes embed
      # libghostty (the app vendors ghostty), so the rendering engine is
      # already Ghostty's; the font matches via this settings file.
      #
      # Only settings.json is a managed symlink. keys.json is GENERATED
      # by the activation below from the herdr TUI's config.toml (the
      # single source of truth for the shared ctrl+a scheme), so the two
      # tools cannot drift: herdr --default-config pins the TUI's
      # baked-in defaults from the installed binary, config.toml applies
      # user overrides, and this option adds desktop-only bindings.
      #
      # herdr-app rewrites everything else in ~/.config/herdr-app on
      # every start (AGENTS.md, view.json, shared.json, ...) and only
      # installs defaults when a user file is missing, so a generated
      # keys.json is read but never stomped. Invalid output — or rather,
      # a schema or keystroke the app rejects — shows up as keys.error
      # next to the file.
      ".config/herdr-app/settings.json".source = src.file "settings.json";
    };

    home.activation.herdrAppKeys =
      # Runs after writeBoundary so settings.json's parent directory and
      # the herdr TUI's config.toml symlink both exist. Reading config.toml
      # through the live symlink (not a store path) also picks up edits
      # made between switches, keeping the regenerated file exactly in
      # sync with what the TUI currently runs.
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.config/herdr-app
        $DRY_RUN_CMD ${generateKeys} \
          --config ${config.home.homeDirectory}/.config/herdr/config.toml \
          --herdr ${pkgs.herdr}/bin/herdr \
          --defaults ${./defaults-keys.macos.json} \
          --extra ${
          pkgs.writeText "herdr-app-extra-keys.json" (builtins.toJSON cfg.extraKeys)
        } \
          --out ${config.home.homeDirectory}/.config/herdr-app/keys.json
      '';
  };
}
