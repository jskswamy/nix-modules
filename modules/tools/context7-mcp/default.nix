{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.context7-mcp;
in {
  imports = [
    ../../_common
    ../../theme
    ../_mcp-common
  ];

  options.tools.context7-mcp = {
    enable = mkToolEnable lib "context7-mcp";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.context7-mcp or null;
      description = ''
        Package providing context7-mcp, installed when this tool is enabled.

        Set to null to configure it without installing anything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

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
          PATH = config.mcp.daemonPath;
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${config.mcp.logDir}/context7-mcp.log";
        StandardErrorPath = "${config.mcp.logDir}/context7-mcp.log";
      };
    };
  };
}
