{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/oh-my-posh/config";
  fishSrc = mkSource config ./fish "modules/tools/oh-my-posh/fish";
  cfg = config.tools.oh-my-posh;
  omp = lib.getExe config.programs.oh-my-posh.package;
  themeDir = "${config.xdg.configHome}/oh-my-posh";

  # Merge a command statusLine into a harness's settings.json on every
  # activation, leaving its other keys alone. Skipped when the file is a
  # symlink (something else owns it) or not valid JSON (jq fails), so
  # nothing is clobbered.
  mergeStatusLine = settings: command: let
    statusLine = builtins.toJSON {
      type = "command";
      inherit command;
    };
  in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      settings=${lib.escapeShellArg settings}
      if [ ! -L "$settings" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$settings")"
        tmp="$(mktemp)"
        if { if [ -s "$settings" ]; then cat "$settings"; else echo '{}'; fi; } \
          | ${pkgs.jq}/bin/jq '.statusLine = ${statusLine}' > "$tmp"; then
          $DRY_RUN_CMD mv "$tmp" "$settings"
        else
          rm -f "$tmp"
        fi
      fi
    '';
in {
  imports = [
    ../../_common
    ../../theme
    ../../prompt
  ];

  options.tools.oh-my-posh = {
    enable = mkToolEnable lib "oh-my-posh";

    statusLine = {
      antigravity.enable = lib.mkEnableOption ''
        Oh My Posh as the Antigravity CLI statusline, rendered with
        antigravity.toml. Merges a statusLine entry into
        ~/.gemini/antigravity-cli/settings.json on every activation'';

      pi.enable = lib.mkEnableOption ''
        Oh My Posh as the Pi statusline. Pi has no statusline of its own;
        the pi-statusline extension (installed by tools.skillshare) feeds it
        a Claude Code-style payload, so this reuses claude.toml. Merges a
        statusLine entry into ~/.pi/agent/settings.json, the only settings
        file the extension reads, so it covers every Pi profile'';
    };
  };

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

      # Source the `set_poshcontext` hook after `oh-my-posh init fish` (which
      # defines an empty `set_poshcontext` stub in shellInit). Placed outside
      # conf.d/ so Fish does not source it prematurely before init.
      programs.fish.interactiveShellInit = lib.mkAfter ''
        if test -f ~/.config/fish/oh-my-posh.fish
          source ~/.config/fish/oh-my-posh.fish
        end
      '';

      home.file = {
        ".config/oh-my-posh/config.toml".source = src.file "config.toml";
        # Agent statusline themes, for `oh-my-posh <agent> --config <this>`.
        ".config/oh-my-posh/claude.toml".source = src.file "claude.toml";
        ".config/oh-my-posh/antigravity.toml".source = src.file "antigravity.toml";
        ".config/fish/oh-my-posh.fish".source = fishSrc.file "oh-my-posh.fish";
      };

      home.activation = {
        ompAntigravityStatusLine = lib.mkIf cfg.statusLine.antigravity.enable (
          mergeStatusLine "${config.home.homeDirectory}/.gemini/antigravity-cli/settings.json"
          "${omp} antigravity --config ${themeDir}/antigravity.toml"
        );
        ompPiStatusLine = lib.mkIf cfg.statusLine.pi.enable (
          mergeStatusLine "${config.home.homeDirectory}/.pi/agent/settings.json"
          "${omp} claude --config ${themeDir}/claude.toml"
        );
      };
    })
  ];
}
