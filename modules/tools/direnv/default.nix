{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.direnv;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.direnv.enable = mkToolEnable lib "direnv";

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = lib.mkDefault true;
      nix-direnv.enable = lib.mkDefault true;

      config = {
        hide_env_diff = lib.mkDefault true;
        disable_stdin = lib.mkDefault true;
        strict_env = lib.mkDefault true;
      };

      stdlib = ''
        use_claude_profile() {
          local profile="''${1:-personal}"
          case "$profile" in
            personal)
              export CLAUDE_CONFIG_DIR="$HOME/.claude"
              ;;
            work)
              export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
              ;;
            *)
              log_error "Unknown Claude profile: $profile"
              return 1
              ;;
          esac
          log_status "Claude profile: $profile"
        }

        # Reuse an existing .venv (or a named one) instead of direnv creating a
        # fresh one under .direnv/ - lets nested project dirs opt into a venv
        # with just `layout venv` instead of repeating VIRTUAL_ENV each time.
        layout_venv() {
          export VIRTUAL_ENV="''${1:-.venv}"
          layout python3
        }
      '';
    };
  };
}
