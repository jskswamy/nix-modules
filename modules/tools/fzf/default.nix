{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  fishSrc = mkSource config ./fish "modules/tools/fzf/fish";
  cfg = config.tools.fzf;
in {
  imports = [
    ../fd
    ../../_common
    ../../theme
  ];

  options.tools.fzf = {
    enable = mkToolEnable lib "fzf";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.fzf;
      description = ''
        Package providing fzf, installed when this tool is enabled.

        Set to null to configure fzf without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;
    home.sessionVariables = {
      FZF_TMUX = "1";
      FZF_TMUX_HEIGHT = "80";
      FZF_ALT_C_COMMAND = "fd -t d . $HOME";
      FZF_CTRL_T_COMMAND = "fd . $HOME/source/ --exclude vendor --exclude node_modules";
      FZF_CTRL_T_OPTS = "--preview 'bat --color always {} 2>/dev/null or cat -n {} || eza --color always -l --git --git-ignore {} 2>/dev/null || tree -C {} 2>/dev/null | head -200' --select-1 --exit-0";
      FZF_CTRL_R_OPTS = "--sort --exact --preview 'echo {}' --preview-window down:3:hidden:wrap --bind '?:toggle-preview'";
      FZF_DEFAULT_OPTS = "--color=16,fg+:-1:reverse,bg+:-1,hl+:-1:reverse";
    };
    home.file.".config/fish/conf.d/fzf.fish".source = fishSrc.file "fzf.fish";
  };
}
