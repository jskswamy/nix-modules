# 1mcp: aggregates the stdio-only MCP servers that have no native HTTP
# mode (git, time, sequential-thinking, codebase-memory, chrome-devtools,
# noteplan). 1mcp spawns each backend ONCE as a singleton and multiplexes
# every client session through it via request-ID namespacing — unlike
# agentgateway, which has no way to share a stdio backend across sessions.
#
# Registered as its own top-level Claude Code connector rather than proxied
# through agentgateway: agentgateway's tools/list fan-out drops any
# upstream's tools past the first pagination page with no signal to the
# client (confirmed in source), which silently truncated 1mcp's 103 tools
# down to ~20.
#
# Its server list lives at ~/.config/1mcp/mcp.json, which this module does
# not ship — that file pins absolute paths to server binaries, so it
# belongs to the consumer.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.local-mcp;
  url = "http://127.0.0.1:${toString cfg.port}/mcp";
in {
  imports = [
    ../../_common
    ../../theme
    ../_mcp-common
  ];

  options.tools.local-mcp = {
    enable = mkToolEnable lib "local-mcp";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3051;
      description = "Port 1mcp listens on, and the one Claude Code is pointed at.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Package providing 1mcp, installed when this tool is enabled.

        Defaults to null: 1mcp is run straight from npm via npx, pinned in
        the launchd agent below, so there is nothing to install.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;

      activation.configureClaudeCodeLocalMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if command -v claude &> /dev/null; then
          $DRY_RUN_CMD claude mcp add --transport http 1mcp "${url}" --scope user 2>/dev/null || true
        fi
      '';
    };

    launchd.agents.local-mcp = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.nodejs_24}/bin/npx"
          "-y"
          "@1mcp/agent@0.36.0"
          "--config"
          "${config.home.homeDirectory}/.config/1mcp/mcp.json"
          "--port"
          "3051"
        ];
        EnvironmentVariables = {
          PATH = "${config.mcp.daemonPath}:${pkgs.nodejs_24}/bin";
        };
        RunAtLoad = true;
        KeepAlive = true;
        WatchPaths = [
          "${config.home.homeDirectory}/.config/1mcp/mcp.json"
        ];
        StandardOutPath = "${config.mcp.logDir}/local-mcp.log";
        StandardErrorPath = "${config.mcp.logDir}/local-mcp.log";
      };
    };
  };
}
