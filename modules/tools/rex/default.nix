{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable prefixKeyAssertions allMatches;
  src = mkSource config ./config "modules/tools/rex/config";
  cfg = config.tools.rex;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  inherit (config.theme) variant;
  t = config.terminal;

  # Shared prefix keys (terminal.keys) as Rex actions. equalize and
  # resizeMode are Lua actions defined in init.lua.
  actions = {
    splitRight = "pane.split.right";
    splitDown = "pane.split.down";
    focusLeft = "pane.focus.left";
    focusDown = "pane.focus.down";
    focusUp = "pane.focus.up";
    focusRight = "pane.focus.right";
    focusNext = "pane.focus_next";
    focusPrevious = "pane.focus_previous";
    closePane = "pane.close";
    zoom = "pane.zoom";
    equalize = "pane_or_float_balance";
    resizeMode = "resize_mode_open";
    newTab = "client.tab.new";
    nextTab = "client.tab.next";
    previousTab = "client.tab.previous";
    renameTab = "client.tab.rename";
    closeTab = "client.tab.close";
  };
  bind = key: action: "rex.bind(${builtins.toJSON key}, ${builtins.toJSON action})\n";
  terminalLua =
    lib.concatStrings (lib.mapAttrsToList (action: keys:
        lib.concatMapStrings (key: bind "ctrl+a>${key}" actions.${action}) keys)
      # Unknown actions are dropped here and reported by the assertion below.
      (lib.filterAttrs (action: _: actions ? ${action}) cfg.keys))
    + lib.optionalString (t.hotkey.app == "rex") (bind t.hotkey.key "client.visibility.toggle");

  # ctrl+a keys init.lua binds itself. Lua escapes a backslash as "\\";
  # tabs 1-9 are bound in a loop, so they are added by hand.
  reservedKeys =
    map (lib.replaceStrings ["\\\\"] ["\\"])
    (allMatches lib "rex\\.bind\\(\"ctrl\\+a>([^\"]+)\"" (builtins.readFile ./config/init.lua))
    ++ map toString (lib.range 1 9);

  rexBin =
    if cfg.package != null
    then lib.getExe cfg.package
    else "${config.home.homeDirectory}/.local/bin/rex";
in {
  imports = [
    ../../_common
    ../../theme
    ../../terminal
    ../nexo
  ];

  options.tools.rex = {
    enable = mkToolEnable lib "rex";

    keys = lib.mkOption {
      type = with lib.types; attrsOf (listOf str);
      default = {};
      example = {splitRight = ["v"];};
      description = ''
        Rex's ctrl+a prefix keys, by action. Filled from the shared
        `terminal.keys` as defaults; set an action here to change it for
        Rex only.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Package providing the rex CLI, installed when this tool is enabled.

        Defaults to null — on macOS the Rex app bundle (installed in
        `/Applications/Rex.app` or `/Applications/Rex Beta.app`) embeds the
        `rex` server and CLI binary, and this module installs a wrapper at
        `~/.local/bin/rex` that delegates to it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    tools.rex.keys = lib.mapAttrs (_: lib.mkDefault) t.keys;
    assertions = prefixKeyAssertions lib {
      option = "tools.rex.keys";
      inherit (cfg) keys;
      inherit actions;
      reserved = reservedKeys;
    };

    home = {
      packages = lib.optional (cfg.package != null) cfg.package;

      file =
        {
          ".config/rex/init.lua".source = src.file "init.lua";
          # Loaded by init.lua: shared prefix keys, plus the global hotkey
          # when Rex owns it.
          ".config/rex/terminal.lua".text = terminalLua;
        }
        // lib.optionalAttrs (isDarwin && cfg.package == null) {
          ".local/bin/rex" = {
            source = ./scripts/rex;
            executable = true;
          };
        };

      activation.rexReload = lib.hm.dag.entryAfter ["writeBoundary" "linkGeneration"] ''
        if [[ ! -v DRY_RUN ]] && [[ -x ${lib.escapeShellArg rexBin} ]]; then
          ${lib.escapeShellArg rexBin} --autostart=false config reload >/dev/null 2>&1 || true
        fi
      '';
    };

    # Declarative macOS GUI & terminal settings (com.superlogical.rex).
    targets.darwin.defaults."com.superlogical.rex" = lib.mkIf isDarwin (lib.mapAttrs (_: lib.mkDefault) ({
        "rex.client.remoteControl" = true;

        # Shared look-and-feel (modules/terminal).
        "Workspace.terminalFontName" = t.font.family;
        "Workspace.terminalFontPointSize" = t.font.size * 1.0;
        "Workspace.terminalAllowsLigatures" = t.font.ligatures;
        # Face policy from the shared terminal options: bold draws with
        # the font's true Bold face when the family has one (Fira Code
        # does, its Italic is not a face), and boldItalic still forces
        # both on with synthesis for what is missing.
        "Workspace.terminalSynthesizesMissingStyles" = t.boldItalic;
        "Workspace.terminalUsesBoldFace" = t.face.bold;
        "Workspace.terminalUsesItalicFace" = t.face.italic;
        "Workspace.terminalCharacterSpacing" = "${toString t.cell.widthPercent}%";
        "Workspace.terminalCellHeightPercent" = t.cell.heightPercent * 1.0;
        "Workspace.terminalCopyOnSelect" = t.copyOnSelect;
        "Workspace.terminalCursorStyle" = t.cursor.style;
        "Workspace.terminalCursorStyleForced" = true;
        # Rex has no blink toggle; a custom 0 ms interval is how it says "never".
        "Workspace.terminalCursorBlinkUsesCustomInterval" = !t.cursor.blink;
        "Workspace.terminalCursorBlinkIntervalMilliseconds" = 0;
        "Workspace.balancesSplitsOnCreation" = true;
        "Workspace.experiments.groupsActivityByPriority" = true;
        "Workspace.activityGrouping" = "priority";

        # Appearance, from theme.variant like the other terminals. Merino is
        # built into Rex; another variant must be imported once in Rex
        # (Settings → Themes → Import Theme) under the same ID.
        "Workspace.lightThemeID" = "${variant}-light";
        "Workspace.darkThemeID" = "${variant}-dark";
        "Workspace.terminalFontSmoothing" = true;
        "Workspace.terminalSmoothScrolling" = true;
        "Workspace.cursorShadersEnabled" = true;
        "Workspace.animationStyle" = "snappy";
        "Workspace.tabIconTintMode" = "off";

        # Panes and windows.
        "Workspace.toolbarBehavior" = "alwaysShow";
        "Workspace.focusFollowsMouse" = true;
        "Workspace.inactivePaneFadeMode" = "both";
        "Workspace.usesStandardInactiveWindowPaneStyles" = true;
        "Workspace.showsProgramActivityNotifications" = false;
        "Workspace.experiments.usesNewQuickSwitcher" = true;

        "rex.agents.names-sessions" = true;

        # Developer mode and its server settings (Settings → Server). Tailnet
        # access is left out: it needs a one-time Tailscale login per machine.
        "rex.developer-mode-enabled" = true;
        "rex.server.run-mode" = "bundled";
        "rex.server.automatic-restart-enabled" = true;
        "rex.server.block-plugin-reload-enabled" = false;
        "rex.server.web-client-origin-patterns" = ["https://rex.superlogical.com"];
      }
      // {
        # composesText is Rex's "Composes characters"; written so turning
        # optionAsAlt off also clears an earlier actsAsAlt.
        "Workspace.terminalOptionKeyBehavior" =
          if t.optionAsAlt
          then "actsAsAlt"
          else "composesText";
      }));
  };
}
