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

  options.tools.mcp = {
    enable = mkToolEnable lib "mcp";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
          Package providing mcp, installed when this tool is enabled.

          This module configures several MCP servers rather than one
        program, so there is no single package to install. The servers
        themselves come from the consumer's own package list.

        Set to null to configure mcp without installing it — for a
          binary that comes from the system, Homebrew, or a language
          package manager instead.
      '';
    };
  };

  # services.nix holds the launchd agents and the Claude Code activation
  # script. Merged in here so it is gated by tools.mcp.enable.
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {home.packages = lib.optional (cfg.package != null) cfg.package;}
    (import ./services.nix {inherit config lib pkgs;})
    {
      # MCP configuration (AgentGateway server definitions)
      home.file.".config/agentgateway/config.yaml".source =
        src.file "config.yaml";
    }
  ]);
}
