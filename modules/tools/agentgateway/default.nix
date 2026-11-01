# AgentGateway: routes Claude Code to the Things Cloud MCP server.
#
# Server definitions live in config.yaml, symlinked for instant edits.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable ownPkg;
  src = mkSource config ./config "modules/tools/agentgateway/config";
  cfg = config.tools.agentgateway;
  url = "http://127.0.0.1:${toString cfg.port}/mcp";
  stateDir = "${config.xdg.stateHome}/agentgateway";
  keyFile = "${stateDir}/session.key";
in {
  imports = [
    ../../_common
    ../../theme
    ../_mcp-common
  ];

  options.tools.agentgateway = {
    enable = mkToolEnable lib "agentgateway";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3050;
      description = "Port the gateway listens on, and the one Claude Code is pointed at.";
    };

    registerMcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Register the gateway directly with Claude Code through `claude mcp add`.

        Disable when another module, such as `tools.skillshare`, registers it.
      '';
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default =
        # Upstream publishes an aarch64-darwin binary only, and the launchd
        # agent below is darwin-only anyway.
        if pkgs.stdenv.hostPlatform.system == "aarch64-darwin"
        then ownPkg pkgs "agentgateway"
        else null;
      description = ''
        Package providing agentgateway, installed when this tool is enabled.

        Set to null to configure it without installing anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      packages = lib.optional (cfg.package != null) cfg.package;

      file.".config/agentgateway/config.yaml".source = src.file "config.yaml";

      # Claude Code does not read ~/.claude/.mcp.json; it keeps user-scoped
      # MCP config in ~/.claude.json via the CLI. `claude mcp add` is
      # idempotent, reporting "MCP server already exists" on repeat runs.
      activation = {
        agentgatewaySessionKey = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryBetween ["setupLaunchAgents"] ["writeBoundary"] ''
          if [[ ! -v DRY_RUN ]]; then
            (
              set -e
              umask 077
              state_dir=${lib.escapeShellArg stateDir}
              key_file=${lib.escapeShellArg keyFile}
              if [[ -L "$state_dir" || -L "$key_file" ]]; then
                echo "agentgateway: refusing symlinked session state" >&2
                exit 1
              fi
              ${pkgs.coreutils}/bin/mkdir -p "$state_dir"
              ${pkgs.coreutils}/bin/chmod 700 "$state_dir"
              if [[ ! -e "$key_file" ]]; then
                temporary="$(${pkgs.coreutils}/bin/mktemp "$state_dir/.session-key.XXXXXX")"
                trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
                ${pkgs.openssl}/bin/openssl rand -hex 32 > "$temporary"
                # Publish a complete key without replacing a concurrent activation's key.
                ${pkgs.coreutils}/bin/ln -T "$temporary" "$key_file" 2>/dev/null || [[ -f "$key_file" && ! -L "$key_file" ]]
              fi
              if [[ ! -f "$key_file" || -L "$key_file" ]] ||
                [[ "$(${pkgs.coreutils}/bin/wc -c < "$key_file")" -gt 65 ]] ||
                ! ${pkgs.gnugrep}/bin/grep -Eq '^[0-9a-fA-F]{64}$' "$key_file"; then
                echo "agentgateway: invalid machine-local session key; refusing to rotate it" >&2
                exit 1
              fi
              ${pkgs.coreutils}/bin/chmod 600 "$key_file"
            )
          fi
        '');
        configureClaudeCodeAgentgateway = lib.mkIf cfg.registerMcp (lib.hm.dag.entryAfter ["writeBoundary"] ''
          if command -v claude &> /dev/null; then
            $DRY_RUN_CMD claude mcp add --transport http agentgateway "${url}" --scope user 2>/dev/null || true
          fi
        '');
      };
    };

    launchd.agents.agentgateway = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.bash}/bin/bash"
          "-c"
          ''
            session_key_file=${lib.escapeShellArg keyFile}
            [[ -f "$session_key_file" && ! -L "$session_key_file" ]] || exit 1
            SESSION_KEY="$(${pkgs.coreutils}/bin/cat "$session_key_file")" || exit 1
            [[ "$SESSION_KEY" =~ ^[0-9a-fA-F]{64}$ ]] || exit 1
            export SESSION_KEY
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
        StandardOutPath = "${config.mcp.logDir}/stdout.log";
        StandardErrorPath = "${config.mcp.logDir}/stderr.log";

        EnvironmentVariables = {
          PATH = config.mcp.daemonPath;
        };

        # Process control
        ProcessType = "Interactive";
        Nice = 0;

        # macOS launchd's default NOFILE limit (256 soft) is too low for a
        # proxy holding many concurrent HTTP connections. The only target is
        # HTTP (things-cloud, see config.yaml), but keep the headroom as cheap
        # insurance against connection-count bursts.
        SoftResourceLimits.NumberOfFiles = 8192;
        HardResourceLimits.NumberOfFiles = 8192;
      };
    };
  };
}
