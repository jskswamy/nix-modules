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
  ];

  options.tools.git.enable = mkToolEnable lib "git";

  config = lib.mkIf cfg.enable {
    # Kept in its own file so the long settings block stays as written.
    programs.git = import ./git.nix {inherit config;};

    home.file.".local/bin/git-ai-commit" = {
      source = ./scripts/git-ai-commit;
      executable = true;
    };
  };
}
