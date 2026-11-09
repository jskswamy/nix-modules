{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable prefixKeyAssertions allMatches;
  src = mkSource config ./config "modules/tools/ghostty/config";
  cfg = config.tools.ghostty;
  inherit (config.theme) variant;
  t = config.terminal;

  # Shared look-and-feel (modules/terminal), as Ghostty keys. Each is a
  # default, so tools.ghostty.settings overrides any one of them.
  # Ghostty treats only `false` specially; any other value is a style
  # name, so the shared face policy maps true -> "default" (the font's
  # own Bold/Italic face) and false -> false (draw as regular text).
  styleKey = on:
    if on
    then "default"
    else false;

  sharedSettings =
    {
      font-family = t.font.family;
      font-size = t.font.size;
      adjust-cell-height = "${toString t.cell.heightPercent}%";
      adjust-cell-width = "${toString t.cell.widthPercent}%";
      font-style-bold = styleKey t.face.bold;
      font-style-italic = styleKey t.face.italic;
      font-style-bold-italic = styleKey (t.face.bold && t.face.italic);
      font-synthetic-style = t.boldItalic;
      cursor-style = t.cursor.style;
      cursor-style-blink = t.cursor.blink;
      copy-on-select =
        if t.copyOnSelect
        then "clipboard"
        else false;
      macos-option-as-alt = t.optionAsAlt;
    }
    // lib.optionalAttrs (!t.font.ligatures) {font-feature = "-calt,-liga,-dlig";};

  # Shared prefix keys (terminal.keys) as Ghostty actions.
  prefix = "ctrl+b";
  actions = {
    splitRight = "new_split:right";
    splitDown = "new_split:down";
    focusLeft = "goto_split:left";
    focusDown = "goto_split:down";
    focusUp = "goto_split:up";
    focusRight = "goto_split:right";
    focusNext = "goto_split:next";
    focusPrevious = "goto_split:previous";
    closePane = "close_surface";
    zoom = "toggle_split_zoom";
    equalize = "equalize_splits";
    resizeMode = "activate_key_table:resize";
    newTab = "new_tab";
    nextTab = "next_tab";
    previousTab = "previous_tab";
    renameTab = "prompt_surface_title";
    closeTab = "close_tab";
  };
  # Unknown actions are dropped here and reported by the assertion below.
  keybinds = lib.concatStrings (lib.mapAttrsToList (action: keys:
    lib.concatMapStrings (key: "keybind = ${prefix}>${key}=${actions.${action}}\n") keys)
  (lib.filterAttrs (action: _: actions ? ${action}) cfg.keys));

  # ctrl+b keys the hand-written config binds itself (tab 1-9, quick terminal).
  reservedKeys = allMatches lib "(^|\n)keybind = ctrl\\+b>([^=\n]+)=" (builtins.readFile ./config/config);

  terminalConf =
    lib.generators.toKeyValue {mkKeyValue = lib.generators.mkKeyValueDefault {} " = ";} cfg.settings
    + keybinds
    + lib.optionalString (t.hotkey.app == "ghostty") "keybind = global:${t.hotkey.key}=toggle_visibility\n";

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
    ../../terminal
  ];

  options.tools.ghostty = {
    enable = mkToolEnable lib "ghostty";

    keys = lib.mkOption {
      type = with lib.types; attrsOf (listOf str);
      default = {};
      example = {splitRight = ["v"];};
      description = ''
        Ghostty's ctrl+b prefix keys, by action. Filled from the shared
        `terminal.keys` as defaults; set an action here to change it for
        Ghostty only.
      '';
    };

    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [str bool int float]);
      default = {};
      example = {font-size = 14;};
      description = ''
        Ghostty keys written to the generated terminal.conf. Filled with
        the shared `terminal.*` values as defaults; set a key here to
        override it for Ghostty only. Use this rather than the
        hand-written config: Ghostty loads terminal.conf after that file,
        so a key set there is overridden.
      '';
    };

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
    tools.ghostty.settings = lib.mapAttrs (_: lib.mkDefault) sharedSettings;
    tools.ghostty.keys = lib.mapAttrs (_: lib.mkDefault) t.keys;
    assertions = prefixKeyAssertions lib {
      option = "tools.ghostty.keys";
      inherit (cfg) keys;
      inherit actions;
      reserved = reservedKeys;
    };

    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.file = {
      ".config/ghostty/config".source = src.file "config";

      # Included by config/ghostty/config via `config-file = ?~/.config/ghostty/theme.conf`,
      # so the rest of that file stays a plain instant-edit symlink.
      ".config/ghostty/terminal.conf".text = terminalConf;
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
