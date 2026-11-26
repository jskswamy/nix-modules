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

  # Single quotes are the one fish quoting form with no expansion; inside
  # them only \\ and \' are escapes.
  fishQuote = v: "'" + lib.replaceStrings ["\\" "'"] ["\\\\" "\\'"] v + "'";

  # The legacy flat `orgs` list is the `client` context; named contexts win.
  contexts =
    lib.optionalAttrs (cfg.repoContext.orgs != []) {
      client = {
        name = "client";
        inherit (cfg.repoContext) orgs;
        color = "#fab387";
        icon = "";
      };
    }
    // cfg.repoContext.contexts;
  # One row per org, so the hook can index name/color/icon by the matched org.
  contextRows = lib.concatLists (lib.mapAttrsToList
    (_: c: map (org: {inherit org; inherit (c) name color icon;}) c.orgs)
    contexts);
  fishList = var: field:
    "set -g ${var} " + lib.concatMapStringsSep " " (r: fishQuote r.${field}) contextRows;
in {
  imports = [
    ../../_common
    ../../theme
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
        orgs. Shorthand for a `client` entry in `repoContext.contexts`.
        The list is an option rather than part of that file so the function
        can live in a public repo while the org names stay wherever the
        consumer keeps its private configuration.
      '';
    };

    repoContext.contexts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({name, ...}: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = name;
            defaultText = lib.literalMD "the attribute name";
            example = "Acme Corp";
            description = "Label shown in the prompt pill; spaces and capitals are fine.";
          };
          orgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "GitHub orgs whose repos belong to this context.";
          };
          color = lib.mkOption {
            type = lib.types.str;
            default = "#fab387";
            description = "Hex colour for this context's prompt pill and accent.";
          };
          icon = lib.mkOption {
            type = lib.types.str;
            default = "";
            example = "🏢";
            description = "Emoji or glyph shown before the context name.";
          };
        };
      }));
      default = {};
      example = {
        acme = {
          orgs = ["acme-corp"];
          color = "#f38ba8";
          icon = "🏢";
        };
      };
      description = ''
        Named repo contexts. When the current directory, or a worktree's
        remote, belongs to one of a context's orgs, the repo-context hook
        exports REPO_CONTEXT (its `name`), REPO_CONTEXT_COLOR and
        REPO_CONTEXT_ICON for prompts to render. The first matching org wins.
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
    # instant edits. Fish automatically sources ~/.config/fish/conf.d/*.fish
    # at startup — do NOT re-source them in interactiveShellInit, as that
    # runs every conf.d file (and its subprocesses) twice on every new shell.
    programs.fish = {
      enable = lib.mkDefault true;
      plugins = [];
    };

    home.file =
      mirrorDir ".config/fish/functions" "functions"
      // confd
      // lib.optionalAttrs (cfg.env != {}) {
        ".config/fish/conf.d/05-extra-env.fish".text =
          lib.concatStringsSep "\n"
          (lib.mapAttrsToList (n: v: "set -gx ${n} ${fishQuote v}") cfg.env)
          + "\n";
      }
      // lib.optionalAttrs (contextRows != []) {
        # Sorts before 50-repo-context.fish, which consumes these lists.
        ".config/fish/conf.d/49-repo-context-orgs.fish".text =
          lib.concatMapStringsSep "\n" (x: fishList x.var x.field) [
            {
              var = "_REPO_CONTEXT_ORGS";
              field = "org";
            }
            {
              var = "_REPO_CONTEXT_NAMES";
              field = "name";
            }
            {
              var = "_REPO_CONTEXT_COLORS";
              field = "color";
            }
            {
              var = "_REPO_CONTEXT_ICONS";
              field = "icon";
            }
          ]
          + "\n";
      };
  };
}
