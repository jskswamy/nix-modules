{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/rex/config";
  cfg = config.tools.rex;
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  rexBin =
    if cfg.package != null
    then lib.getExe cfg.package
    else "${config.home.homeDirectory}/.local/bin/rex";
in {
  imports = [
    ../../_common
    ../nexo
  ];

  options.tools.rex = {
    enable = mkToolEnable lib "rex";

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
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;

      file =
        {
          ".config/rex/init.lua".source = src.file "init.lua";
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

    # Declarative macOS GUI & terminal settings (com.superlogical.rex),
    # matching the Ghostty typography, cell geometry, cursor, and clipboard
    # configuration.
    targets.darwin.defaults."com.superlogical.rex" = lib.mkIf isDarwin (lib.mapAttrs (_: lib.mkDefault) {
      "rex.client.remoteControl" = true;
      "Workspace.terminalFontName" = "FiraCode Nerd Font Mono";
      "Workspace.terminalFontPointSize" = 12.0;
      "Workspace.terminalAllowsLigatures" = true;
      "Workspace.terminalSynthesizesMissingStyles" = false;
      "Workspace.terminalUsesBoldFace" = false;
      "Workspace.terminalUsesItalicFace" = false;
      "Workspace.terminalCharacterSpacing" = "-5%";
      "Workspace.terminalCellHeightPercent" = 15.0;
      "Workspace.terminalOptionKeyBehavior" = "actsAsAlt";
      "Workspace.terminalCopyOnSelect" = true;
      "Workspace.terminalCursorStyle" = "block";
      "Workspace.terminalCursorStyleForced" = true;
      "Workspace.terminalCursorBlinkUsesCustomInterval" = true;
      "Workspace.terminalCursorBlinkIntervalMilliseconds" = 0;
      "Workspace.balancesSplitsOnCreation" = true;
      "Workspace.experiments.groupsActivityByPriority" = true;
      "Workspace.activityGrouping" = "priority";

      # Appearance, matching the other terminals' Merino pair (theme.variant).
      "Workspace.lightThemeID" = "merino-light";
      "Workspace.darkThemeID" = "merino-dark";
      "Workspace.terminalFontSmoothing" = true;
      "Workspace.terminalSmoothScrolling" = true;
      "Workspace.cursorShadersEnabled" = true;
      "Workspace.animationStyle" = "snappy";
      "Workspace.tabIconTintMode" = "off";

      # Panes and windows.
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
    });
  };
}
