{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/mcp/config";
  cfg = config.tools.mcp;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.mcp.enable = mkToolEnable lib "mcp";

  # services.nix holds the launchd agents and the Claude Code activation
  # script. Merged in here so it is gated by tools.mcp.enable.
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (import ./services.nix {inherit config lib pkgs;})
    {
      # MCP configuration (AgentGateway server definitions)
      home.file.".config/agentgateway/config.yaml".source =
        src.file "config.yaml";
    }
  ]);
}
