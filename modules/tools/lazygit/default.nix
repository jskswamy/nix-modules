{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.lazygit;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.lazygit.enable = mkToolEnable lib "lazygit";

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = lib.mkDefault true;
      settings = {
        gui.theme = {
          selectedLineBgColor = ["reverse"];
          selectedRangeBgColor = ["reverse"];
        };
        git.autoFetch = lib.mkDefault false;
        staging = {
          # false = line-by-line mode by default, true = hunk mode
          useHunkModeInStagingView = lib.mkDefault false;
        };
        customCommands = [
          {
            key = "C";
            context = "files";
            description = "AI commit with Claude";
            command = "bash ~/.local/bin/lazygit-claude-commit";
            output = "terminal";
          }
        ];
      };
    };

    home.file.".local/bin/lazygit-claude-commit" = {
      source = ./scripts/lazygit-claude-commit;
      executable = true;
    };
  };
}
