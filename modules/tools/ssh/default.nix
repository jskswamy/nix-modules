# SSH client configuration.
#
# Only the generic parts live here. Individual hosts — addresses, users,
# port forwards — are a consumer's own infrastructure and belong in its
# private configuration, layered on top via programs.ssh.settings.
# No files of its own, so the flake's `self` is not needed here.
{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.ssh;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.ssh.enable = mkToolEnable lib "ssh";

  config = lib.mkIf cfg.enable {
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
