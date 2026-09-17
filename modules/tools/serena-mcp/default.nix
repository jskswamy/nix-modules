{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.serena-mcp;
in {
  imports = [
    ../../_common
    ../../theme
    ../_mcp-common
  ];

  options.tools.serena-mcp = {
    enable = mkToolEnable lib "serena-mcp";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Package providing serena-mcp, installed when this tool is enabled.

        Defaults to null: serena is a Python tool, installed through
        uv (`serena-agent`) rather than nixpkgs.

        Set to null to configure it without installing anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

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
          PATH = config.mcp.daemonPath;
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.mcp.logDir}/serena-mcp.log";
        StandardErrorPath = "${config.mcp.logDir}/serena-mcp.log";
      };
    };
  };
}
