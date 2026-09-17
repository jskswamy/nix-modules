# SSH client configuration.
#
# Only the generic parts live here. Individual hosts — addresses, users,
# port forwards — are a consumer's own infrastructure and belong in its
# private configuration, layered on top via programs.ssh.settings.
# No files of its own, so the flake's `self` is not needed here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.ssh;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ssh = {
    enable = mkToolEnable lib "ssh";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.openssh;
      description = ''
        Package providing ssh, installed when this tool is enabled.

        Set to null to configure ssh without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    programs.ssh = {
      enable = lib.mkDefault true;
      # home-manager's built-in "*" defaults are replaced by the explicit
      # block below, so opt out of them rather than merging two sets.
      enableDefaultConfig = lib.mkDefault false;

      includes = [
        # Anything not managed by Nix — machine-local hosts, scratch entries.
        "${config.home.homeDirectory}/.ssh/config_external"
      ];

      settings."*".SetEnv = {
        # Universal fallback TERM, so terminals with their own terminfo
        # (Ghostty, Alacritty) do not break remote sessions.
        TERM = lib.mkDefault "xterm-256color";
      };
    };
  };
}
