# Git and the tools built around it: git, lazygit, gpg, tig, hunk, nbdime.
{self}: {
  config,
  lib,
  ...
}: let
  inherit (import ../../lib) mkSource;
  src = mkSource config self;
  store = rel: self + "/${rel}";
in {
  imports = [
    ../_common
    ../theme
  ];

  programs = {
    # Kept in their own files so these long blocks stay exactly as written.
    git = import ./git.nix {inherit config;};
    gpg = import ./gpg.nix {};

    lazygit = {
      enable = lib.mkDefault true;
      settings = {
        gui.theme = {
          selectedLineBgColor = ["reverse"];
          selectedRangeBgColor = ["reverse"];
        };
        git = {
          autoFetch = lib.mkDefault false;
          diffRenderers = [
            {
              colorArg = "always";
              command = "delta --paging=never";
            }
          ];
        };
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
  };

  home.file = {
    ".config/tig/config".source = src "modules/git-tools/config/tig/config";
    ".config/nbdime/config.json".source = src "modules/git-tools/config/nbdime/config.json";

    # hunk — diff review TUI wrapped by herdr-hunk-diff
    ".config/hunk/config.toml".source = src "modules/git-tools/config/hunk/config.toml";

    ".local/bin/git-ai-commit" = {
      source = store "modules/git-tools/scripts/git-ai-commit";
      executable = true;
    };
    ".local/bin/gpg-sign-wrapper" = {
      source = store "modules/git-tools/scripts/gpg-sign-wrapper";
      executable = true;
    };
    ".local/bin/lazygit-claude-commit" = {
      source = store "modules/git-tools/scripts/lazygit-claude-commit";
      executable = true;
    };
  };
}
