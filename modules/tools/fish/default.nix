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

  # Single quotes are the one fish quoting form with no expansion; inside
  # them only \\ and \' are escapes.
  fishQuote = v: "'" + lib.replaceStrings ["\\" "'"] ["\\\\" "\\'"] v + "'";
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

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {GOPRIVATE = "git.example.com";};
      description = ''
        Extra environment variables exported by every fish session.

        Written to conf.d/05-extra-env.fish, which sorts after
        00-environment.fish, so a variable named here also overrides one
        that file sets. Values are quoted for you. For variables that hold
        internal hostnames, org names or paths this is where a private
        configuration supplies them, keeping them out of the public
        conf.d files.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      lib.mapAttrsToList (n: _: {
        assertion = builtins.match "[A-Za-z_][A-Za-z0-9_]*" n != null;
        message = "tools.fish.env: '${n}' is not a valid variable name.";
      })
      cfg.env;

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
      // lib.optionalAttrs (cfg.env != {}) {
        ".config/fish/conf.d/05-extra-env.fish".text =
          lib.concatStringsSep "\n"
          (lib.mapAttrsToList (n: v: "set -gx ${n} ${fishQuote v}") cfg.env)
          + "\n";
      }
      // lib.optionalAttrs (cfg.repoContext.orgs != []) {
        # Sorts before 50-repo-context.fish, which consumes the variable.
        ".config/fish/conf.d/49-repo-context-orgs.fish".text =
          "set -g _REPO_CONTEXT_ORGS "
          + lib.concatMapStringsSep " " (o: ''"${o}"'') cfg.repoContext.orgs
          + "\n";
      };
  };
}
