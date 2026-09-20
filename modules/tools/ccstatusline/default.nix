{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/ccstatusline/config";
  cfg = config.tools.ccstatusline;

  # The absolute path keeps this working when Claude is started from a
  # context whose PATH lacks the profile; a null package means the binary
  # comes from elsewhere on PATH.
  statusLine = builtins.toJSON {
    type = "command";
    command =
      if cfg.package != null
      then lib.getExe cfg.package
      else "ccstatusline";
    padding = 0;
    refreshInterval = 10;
  };
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ccstatusline = {
    enable = mkToolEnable lib "ccstatusline";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs "ccstatusline";
      description = ''
        Package providing ccstatusline, installed when this tool is enabled.

        Set to null to configure ccstatusline without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };

    claude.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Point Claude Code at ccstatusline by merging a `statusLine` entry
        into ~/.claude/settings.json on every activation.

        ccstatusline can only install itself from its interactive menu, so
        without this a fresh machine has the binary and its config but
        Claude never calls it. Other keys in the file are left alone. The
        file is skipped if it is a symlink, which means something else
        (for instance a dotfile module) already owns it, and skipped with
        an error from jq if it is not valid JSON, so nothing is clobbered.

        Off by default: a machine whose Claude settings already carry a
        statusLine has no need of it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;

      file.".config/ccstatusline/settings.json".source =
        src.file "settings.json";

      activation.configureClaudeStatusLine = lib.mkIf cfg.claude.enable (
        lib.hm.dag.entryAfter ["writeBoundary"] ''
          settings="${config.home.homeDirectory}/.claude/settings.json"
          if [ ! -L "$settings" ]; then
            $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
            tmp="$(mktemp)"
            if { if [ -s "$settings" ]; then cat "$settings"; else echo '{}'; fi; } \
              | ${pkgs.jq}/bin/jq '.statusLine = ${statusLine}' > "$tmp"; then
              $DRY_RUN_CMD mv "$tmp" "$settings"
            else
              rm -f "$tmp"
            fi
          fi
        ''
      );
    };
  };
}
