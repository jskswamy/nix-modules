{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/oh-my-posh/config";
  fishSrc = mkSource config ./fish "modules/tools/oh-my-posh/fish";
  cfg = config.tools.oh-my-posh;
in {
  imports = [
    ../../_common
    ../../theme
    ../../prompt
  ];

  options.tools.oh-my-posh.enable = mkToolEnable lib "oh-my-posh";

  config = lib.mkMerge [
    {
      tools.oh-my-posh.enable = lib.mkDefault (config.shell.prompt == "oh-my-posh");

      assertions = [
        {
          assertion = !(cfg.enable && (config.tools.starship.enable or false));
          message = "tools.oh-my-posh and tools.starship cannot both be enabled; pick one via shell.prompt.";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      # config.toml is symlinked below; edits take effect on the next
      # prompt with no rebuild.
      programs.oh-my-posh = {
        enable = lib.mkDefault true;
        enableFishIntegration = lib.mkDefault true;
        # Zsh is configured with Powerlevel10k in tools.zsh; keep it untouched
        # unless a consumer explicitly opts in.
        enableZshIntegration = lib.mkDefault false;
        configFile = lib.mkDefault "${config.xdg.configHome}/oh-my-posh/config.toml";
      };

      home.file = {
        ".config/oh-my-posh/config.toml".source = src.file "config.toml";
        # Drop-in for fish providing `set_poshcontext` for flake/devbox/aide
        # env vars. Harmless where fish is absent.
        ".config/fish/conf.d/oh-my-posh.fish".source = fishSrc.file "oh-my-posh.fish";
      };
    })
  ];
}
