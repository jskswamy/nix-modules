{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable ownPkg;
  cfg = config.tools.codebase-memory-mcp;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.codebase-memory-mcp = {
    enable = mkToolEnable lib "codebase-memory-mcp";

    ui = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the graph-UI-embedded build (codebase-memory-mcp-ui,
        enables --ui=true) instead of the plain server binary.

        Defaults to false: CLI/MCP usage needs no browser UI. As of
        v0.11.0 upstream's -ui release asset is byte-identical to the
        non-UI one (a release pipeline bug), so this is dormant until a
        later version actually ships a distinct build.
      '';
    };

    registerMcp = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Run `claude mcp add --transport stdio` for this server on
        activation. Defaults to false — the package still installs, but
        Claude Code is left unaware of it; use the CLI directly, or wire
        it up yourself (e.g. through local-mcp's 1mcp aggregation).
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = ownPkg pkgs (
        if cfg.ui
        then "codebase-memory-mcp-ui"
        else "codebase-memory-mcp"
      );
      description = ''
        Package providing codebase-memory-mcp, installed when this tool
        is enabled.

        Set to null to configure it without installing anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    home.activation.registerCodebaseMemoryMcp = lib.mkIf cfg.registerMcp (
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        if command -v claude &> /dev/null; then
          $DRY_RUN_CMD claude mcp add --transport stdio codebase-memory-mcp "${cfg.package}/bin/codebase-memory-mcp" --scope user 2>/dev/null || true
        fi
      ''
    );
  };
}
