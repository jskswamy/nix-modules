{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.mcp-nixos;
in {
  imports = [
    ../../_common
    ../../theme
    ../_mcp-common
  ];

  options.tools.mcp-nixos = {
    enable = mkToolEnable lib "mcp-nixos";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Package providing mcp-nixos, installed when this tool is enabled.

        Defaults to null: mcp-nixos is a Python tool, installed through
        uv rather than nixpkgs.

        Set to null to configure it without installing anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    launchd.agents.mcp-nixos = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      config = {
        ProgramArguments = ["${config.home.homeDirectory}/.local/bin/mcp-nixos"];
        EnvironmentVariables = {
          PATH = config.mcp.daemonPath;
          MCP_NIXOS_TRANSPORT = "http";
          MCP_NIXOS_HOST = "127.0.0.1";
          MCP_NIXOS_PORT = "8083";
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.mcp.logDir}/mcp-nixos.log";
        StandardErrorPath = "${config.mcp.logDir}/mcp-nixos.log";
      };
    };
  };
}
