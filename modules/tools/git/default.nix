{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.git;
in {
  imports = [
    ../../_common
    ../../theme
    # git's pager is `hunk pager`, so git brings hunk with it. Drop it
    # again with `tools.hunk.enable = false` and git keeps its own pager.
    ../hunk
  ];

  options.tools.git.enable = mkToolEnable lib "git";

  config = lib.mkIf cfg.enable {
    # Kept in its own file so the long settings block stays as written.
    programs.git = import ./git.nix {
      inherit config lib;
      hunkEnabled = config.tools.hunk.enable;
    };

    home.file.".local/bin/git-ai-commit" = {
      source = ./scripts/git-ai-commit;
      executable = true;
    };
  };
}
