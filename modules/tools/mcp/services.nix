# MCP Configuration
# Server definitions are in config.yaml (symlinked for instant edits!)
# This file handles: launchd service, Claude Code activation script, directories
{
  config,
  pkgs,
  lib,
  ...
}: let
  agentGatewayPort = "3050";
  agentGatewayUrl = "http://127.0.0.1:${agentGatewayPort}/mcp";
  local1mcpPort = "3051";
  local1mcpUrl = "http://127.0.0.1:${local1mcpPort}/mcp";
  # Nix system paths for the persistent HTTP-mode MCP daemons below (they
  # need their own interpreter/nix-profile deps on PATH, same as every
  # stdio target already does in config.yaml).
  nixSystemPaths = "${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
in {
  home = {
    activation = {
      # Create log directory (local, not synced)
      createAgentGatewayLogDir = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
        lib.hm.dag.entryAfter ["writeBoundary"] ''
          $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.local/share/agentgateway
        ''
      );

      # Configure Claude Code MCP via `claude mcp add` command
      # This is required because Claude Code doesn't recognize ~/.claude/.mcp.json
      # It stores user-scoped MCP config in ~/.claude.json via the CLI
      # The command is idempotent: "MCP server already exists" if already configured
      #
      # Two separate connectors, split by responsibility:
      # - agentgateway: HTTP-native servers (context7, serena, nixos, things-cloud)
      # - 1mcp: stdio-only servers, aggregated by 1mcp itself (see the
      #   local-mcp launchd service below). Registered directly rather than
      #   proxied through agentgateway — agentgateway's tools/list fan-out
      #   drops any upstream's tools past the first pagination page with no
      #   signal to the client (confirmed in source), which silently
      #   truncated 1mcp's 103 tools down to ~20.
      configureClaudeCodeMcp = lib.hm.dag.entryAfter ["writeBoundary"] ''
        if command -v claude &> /dev/null; then
          $DRY_RUN_CMD claude mcp add --transport http agentgateway "${agentGatewayUrl}" --scope user 2>/dev/null || true
          $DRY_RUN_CMD claude mcp add --transport http 1mcp "${local1mcpUrl}" --scope user 2>/dev/null || true
        fi
      '';
    };
  };

  # Launchd service for AgentGateway (macOS only)
  launchd.agents.agentgateway = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.bash}/bin/bash"
        "-c"
        ''
          things_cloud_env="${config.home.homeDirectory}/.config/agenix/things-cloud-mcp.env"
          if [ -r "$things_cloud_env" ]; then
            . "$things_cloud_env"
            if [ -n "''${THINGS_CLOUD_EMAIL:-}" ] && [ -n "''${THINGS_CLOUD_PASSWORD:-}" ]; then
              export THINGS_CLOUD_AUTH="$(printf '%s:%s' "$THINGS_CLOUD_EMAIL" "$THINGS_CLOUD_PASSWORD" | ${pkgs.coreutils}/bin/base64)"
            fi
          fi
          exec ${pkgs.agentgateway}/bin/agentgateway -f "${config.home.homeDirectory}/.config/agentgateway/config.yaml"
        ''
      ];

      # Auto-start on login and keep running
      RunAtLoad = true;
      KeepAlive = true;

      # Automatically restart when config file changes
      WatchPaths = [
        "${config.home.homeDirectory}/.config/agentgateway/config.yaml"
      ];

      # Logging configuration
      StandardOutPath = "${config.home.homeDirectory}/.local/share/agentgateway/stdout.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/agentgateway/stderr.log";

      EnvironmentVariables = {
        PATH = nixSystemPaths;
      };

      # Process control
      ProcessType = "Interactive";
      Nice = 0;

      # macOS launchd's default NOFILE limit (256 soft) is too low for a
      # proxy holding many concurrent HTTP connections. All 4 targets are
      # HTTP (context7/serena/nixos/things-cloud — see config.yaml), so
      # agentgateway itself doesn't spawn stdio subprocesses anymore, but
      # keep the headroom cheap insurance against connection-count bursts.
      SoftResourceLimits.NumberOfFiles = 8192;
      HardResourceLimits.NumberOfFiles = 8192;
    };
  };

  # context7, serena, and mcp-nixos support native HTTP transport and run
  # here as persistent daemons, so agentgateway proxies to them over HTTP
  # instead of spawning a fresh stdio subprocess per MCP session — no idle
  # process footprint, no per-call spawn cost. context7-mcp has no --host
  # flag (binds all interfaces, upstream limitation, accepted); serena and
  # mcp-nixos are pinned to loopback.
  launchd.agents.context7-mcp = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${config.home.homeDirectory}/.nix-profile/bin/context7-mcp"
        "--transport"
        "http"
        "--port"
        "8081"
      ];
      EnvironmentVariables = {
        PATH = nixSystemPaths;
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/.local/share/agentgateway/context7-mcp.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/agentgateway/context7-mcp.log";
    };
  };

  launchd.agents.serena-mcp = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [
        "${config.home.homeDirectory}/.local/bin/serena"
        "start-mcp-server"
        "--transport"
        "streamable-http"
        "--host"
        "127.0.0.1"
        "--port"
        "8082"
        "--enable-web-dashboard"
        "false"
        "--open-web-dashboard"
        "false"
      ];
      EnvironmentVariables = {
        PATH = nixSystemPaths;
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/.local/share/agentgateway/serena-mcp.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/agentgateway/serena-mcp.log";
    };
  };

  launchd.agents.mcp-nixos = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = ["${config.home.homeDirectory}/.local/bin/mcp-nixos"];
      EnvironmentVariables = {
        PATH = nixSystemPaths;
        MCP_NIXOS_TRANSPORT = "http";
        MCP_NIXOS_HOST = "127.0.0.1";
        MCP_NIXOS_PORT = "8083";
      };
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/.local/share/agentgateway/mcp-nixos.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/agentgateway/mcp-nixos.log";
    };
  };

  # 1mcp instance: aggregates the stdio-only MCP servers that have no
  # native HTTP mode (git, time, sequential-thinking, codebase-memory,
  # chrome-devtools, noteplan). 1mcp spawns each backend ONCE as a
  # singleton and multiplexes every client session through it via
  # request-ID namespacing — unlike agentgateway, which has no way to share
  # a stdio backend process across sessions. Registered as its own
  # top-level Claude Code connector (see configureClaudeCodeMcp above),
  # NOT proxied through agentgateway — see config.yaml for why. Pinned to
  # latest (0.36.0) with lazy loading left off — #392 (stale per-session
  # tool snapshot) only triggers with lazy loading enabled, which we have
  # no reason to use here since this doesn't serve an LLM context directly.
  #
  # Trial (see config.yaml) — decide in a week whether agentgateway is
  # earning its keep for just context7/serena/nixos/things-cloud.
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
        PATH = "${nixSystemPaths}:${pkgs.nodejs_24}/bin";
      };
      RunAtLoad = true;
      KeepAlive = true;
      WatchPaths = [
        "${config.home.homeDirectory}/.config/1mcp/mcp.json"
      ];
      StandardOutPath = "${config.home.homeDirectory}/.local/share/agentgateway/local-mcp.log";
      StandardErrorPath = "${config.home.homeDirectory}/.local/share/agentgateway/local-mcp.log";
    };
  };
}
