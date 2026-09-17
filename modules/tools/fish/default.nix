{
  config,
  lib,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/fish/config";
  cfg = config.tools.fish;

  # One home.file entry per file, rather than a single directory symlink,
  # so that home-manager-managed files (fish plugins, completions) can
  # coexist in the same directory instead of being shadowed by it.
  mirrorDir = target: rel:
    lib.mapAttrs'
    (name: _: lib.nameValuePair "${target}/${name}" {source = src.file "${rel}/${name}";})
    (lib.filterAttrs (_: t: t == "regular") (builtins.readDir (./config + "/${rel}")));

  confd = mirrorDir ".config/fish/conf.d" "conf.d";

  # 40-starship.fish only customises a prompt starship itself installs, so
  # it is dropped along with starship rather than left behind as a no-op.
  confdForStarship =
    if config.tools.starship.enable
    then confd
    else lib.filterAttrs (n: _: n != ".config/fish/conf.d/40-starship.fish") confd;
in {
  imports = [
    ../../_common
    ../../theme
    # conf.d/40-starship.fish configures starship's prompt, so fish brings
    # starship with it. Drop it again with `tools.starship.enable = false`.
    ../starship
  ];

  options.tools.fish = {
    enable = mkToolEnable lib "fish";

    repoContext.orgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["acme-corp"];
      description = ''
        GitHub orgs that mark a directory as client work.

        conf.d/50-repo-context.fish exports REPO_CONTEXT=client when the
        current directory, or a worktree's remote, belongs to one of these
        orgs. The list is an option rather than part of that file so the
        function can live in a public repo while the org names stay
        wherever the consumer keeps its private configuration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Nearly all fish config lives in conf.d/*.fish, symlinked below for
    # instant edits. Only things needing Nix package resolution stay here.
    programs.fish = {
      enable = lib.mkDefault true;
      plugins = [];
      # mkAfter so this lands after home-manager's own integrations
      # (zoxide, starship, completions path, GPG_TTY) rather than before
      # them, matching the order these files were written against.
      interactiveShellInit = lib.mkAfter ''
        for f in ~/.config/fish/conf.d/*.fish
          source $f
        end
      '';
    };

    home.file =
      mirrorDir ".config/fish/functions" "functions"
      // confdForStarship
      // lib.optionalAttrs (cfg.repoContext.orgs != []) {
        # Sorts before 50-repo-context.fish, which consumes the variable.
        ".config/fish/conf.d/49-repo-context-orgs.fish".text =
          "set -g _REPO_CONTEXT_ORGS "
          + lib.concatMapStringsSep " " (o: ''"${o}"'') cfg.repoContext.orgs
          + "\n";
      };
  };
}
