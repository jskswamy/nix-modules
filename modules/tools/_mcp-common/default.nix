# Shared by the MCP server modules: the log directory they all write to,
# and the PATH those daemons need.
#
# Imported by path, so the module system includes it once however many MCP
# servers are enabled. Underscore-prefixed, so the flake does not expose it
# as a tool of its own.
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.mcp = {
    logDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/agentgateway";
      description = "Directory the MCP server daemons write their logs to.";
    };

    daemonPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin";
      description = ''
        PATH for the persistent HTTP-mode MCP daemons. They need their own
        interpreter and nix-profile dependencies, the same way every stdio
        target already does in agentgateway's config.yaml.
      '';
    };
  };

  config.home.activation.createAgentGatewayLogDir =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin
    (lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD mkdir -p ${config.mcp.logDir}
    '');
}
