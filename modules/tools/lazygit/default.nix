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
    # Two of lazygit's custom commands shell out to hunk, so lazygit brings
    # hunk with it. Drop it with `tools.hunk.enable = false`; the two
    # keybindings go with it and the rest of lazygit is unaffected.
    ../hunk
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
        customCommands =
          [
            {
              key = "C";
              context = "files";
              description = "AI commit with Claude";
              command = "bash ~/.local/bin/lazygit-claude-commit";
              output = "terminal";
            }
          ]
          ++ lib.optionals config.tools.hunk.enable [
            {
              key = "H";
              context = "commits, subCommits, reflogCommits";
              description = "Review commit with hunk";
              command = "hunk show {{.SelectedCommit.Sha}}";
              output = "terminal";
            }
            {
              key = "H";
              context = "localBranches";
              description = "Review branch tip with hunk";
              command = "hunk show {{.SelectedLocalBranch.Name}}";
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
