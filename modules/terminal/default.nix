# Look-and-feel shared by every terminal app (Ghostty, Rex, Herdr-app,
# Alacritty), so they render text the same way.
#
# Like `theme.variant`, this only declares values. Each tool module maps
# them to its own config format; none of these apps reads another's file.
{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  inherit (config.terminal.hotkey) app;
in {
  # The chosen owner must be enabled, or nothing binds the hotkey.
  config.assertions = lib.optional (app != null) {
    assertion = config.tools.${app}.enable or false;
    message = "terminal.hotkey.app is \"${app}\", but tools.${app} is not enabled, so no app would bind ${config.terminal.hotkey.key}.";
  };

  # Defaults set per action, so overriding one action keeps the rest.
  config.terminal.keys = lib.mapAttrs (_: lib.mkDefault) {
    splitRight = ["v" "shift+\\"];
    splitDown = ["-"];
    focusLeft = ["h"];
    focusDown = ["j"];
    focusUp = ["k"];
    focusRight = ["l"];
    focusNext = ["tab" "'"];
    focusPrevious = ["shift+tab" ";"];
    closePane = ["x"];
    zoom = ["z"];
    equalize = ["0"];
    resizeMode = ["r"];
    newTab = ["c"];
    nextTab = ["n"];
    previousTab = ["p"];
    renameTab = ["," "shift+t"];
    closeTab = ["shift+x"];
  };

  options.terminal = {
    font = {
      family = mkOption {
        type = types.str;
        default = "FiraCode Nerd Font Mono";
        description = "Terminal font family.";
      };
      size = mkOption {
        type = types.number;
        default = 12;
        description = "Terminal font size in points.";
      };
      ligatures = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to draw the font's ligatures (ignored by Alacritty, which has none).";
      };
    };

    cell = {
      # Whole numbers: the apps take "N%" strings, and a float would print as 15.500000%.
      heightPercent = mkOption {
        type = types.int;
        default = 15;
        description = "Extra line height as a percentage of the font's (Ghostty's adjust-cell-height).";
      };
      widthPercent = mkOption {
        type = types.int;
        default = -5;
        description = "Character spacing as a percentage of the font's (Ghostty's adjust-cell-width).";
      };
    };

    boldItalic = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to draw bold and italic text in bold and italic faces.
        When false, every style is drawn in the regular face and nothing
        is synthesized.
      '';
    };

    cursor = {
      style = mkOption {
        type = types.enum ["block" "bar" "underline"];
        default = "block";
        description = "Cursor shape.";
      };
      blink = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the cursor blinks.";
      };
    };

    copyOnSelect = mkOption {
      type = types.bool;
      default = true;
      description = "Whether selecting text copies it to the clipboard.";
    };

    optionAsAlt = mkOption {
      type = types.bool;
      default = true;
      description = "Whether the macOS Option key acts as Alt/Meta.";
    };

    keys = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = {};
      example = {splitRight = ["v"];};
      description = ''
        Keys pressed after each app's prefix (Ghostty ctrl+b, Rex ctrl+a),
        by action. Key syntax is Rex's, which Ghostty also accepts
        ("-", "shift+\\", "tab"). Setting one action replaces only that
        action's keys. Herdr is not generated: its config.toml stays
        hand-edited, and its built-in defaults use these same keys.
      '';
    };

    hotkey = {
      app = mkOption {
        type = types.nullOr (types.enum ["rex" "ghostty"]);
        default =
          if config.tools.rex.enable or false
          then "rex"
          else null;
        defaultText = lib.literalExpression ''if config.tools.rex.enable then "rex" else null'';
        description = ''
          The one app that owns the global show/hide hotkey. A global
          hotkey can only belong to one app, so only this app binds it.
          null binds it nowhere. Choosing an app that is not enabled is
          an evaluation error.
        '';
      };
      key = mkOption {
        type = types.str;
        default = "cmd+escape";
        description = "The global hotkey, in Rex/Ghostty key syntax (both accept cmd+escape).";
      };
    };
  };
}
