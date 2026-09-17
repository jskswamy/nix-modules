# Interactive shell: fish (the daily driver), zsh, starship, direnv.
{self}: {
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../lib) mkSource;
  src = mkSource config self;

  # One home.file entry per file, rather than a single directory symlink,
  # so that home-manager-managed files (fish plugins, completions) can
  # coexist in the same directory instead of being shadowed by it.
  mirrorDir = target: rel:
    lib.mapAttrs'
    (name: _: lib.nameValuePair "${target}/${name}" {source = src "${rel}/${name}";})
    (lib.filterAttrs (_: t: t == "regular") (builtins.readDir (self + "/${rel}")));

  cfg = config.shell;
in {
  imports = [
    ../_common
    ../theme
  ];

  options.shell.repoContext.orgs = lib.mkOption {
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

  config = {
    programs = {
      # Nearly all fish config lives in conf.d/*.fish, symlinked below for
      # instant edits. Only things needing Nix package resolution stay here.
      fish = {
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

      zsh = {
        enable = lib.mkDefault true;
        autocd = lib.mkDefault false;
        plugins = [
          {
            name = "powerlevel10k";
            src = pkgs.zsh-powerlevel10k;
            file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
          }
          {
            name = "powerlevel10k-config";
            src = lib.cleanSource ./config/zsh/config;
            file = "p10k.zsh-theme";
          }
        ];

        initContent = lib.mkBefore ''
          if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
            . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
            . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
          fi

          # Define variables for directories
          export PATH=$HOME/.pnpm-packages/bin:$HOME/.pnpm-packages:$PATH
          export PATH=$HOME/.npm-packages/bin:$HOME/bin:$PATH
          export PATH=$HOME/.local/share/bin:$PATH

          # Remove history data we don't want to see
          export HISTIGNORE="pwd:ls:cd"

          # Vim is my editor
          export ALTERNATE_EDITOR=""
          export EDITOR="vim"
          export VISUAL="vim"

          # nix shortcuts
          shell() {
              nix-shell '<nixpkgs>' -A "$1"
          }

          # Use difftastic, syntax-aware diffing
          alias diff=difft

          # Always color ls and group directories
          alias ls='ls --color=auto'

          # Claude Code profile aliases
          # Default 'claude' uses ~/.claude (personal) - no alias needed
          alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'
          alias claude-personal='CLAUDE_CONFIG_DIR=$HOME/.claude claude'
        '';
      };

      # starship.toml is symlinked below; edits take effect on the next
      # prompt with no rebuild.
      starship = {
        enable = lib.mkDefault true;
        enableFishIntegration = lib.mkDefault true;
      };

      direnv = {
        enable = lib.mkDefault true;
        nix-direnv.enable = lib.mkDefault true;

        config = {
          hide_env_diff = lib.mkDefault true;
          disable_stdin = lib.mkDefault true;
          strict_env = lib.mkDefault true;
        };

        stdlib = ''
          use_claude_profile() {
            local profile="''${1:-personal}"
            case "$profile" in
              personal)
                export CLAUDE_CONFIG_DIR="$HOME/.claude"
                ;;
              work)
                export CLAUDE_CONFIG_DIR="$HOME/.claude-work"
                ;;
              *)
                log_error "Unknown Claude profile: $profile"
                return 1
                ;;
            esac
            log_status "Claude profile: $profile"
          }

          # Reuse an existing .venv (or a named one) instead of direnv creating a
          # fresh one under .direnv/ - lets nested project dirs opt into a venv
          # with just `layout venv` instead of repeating VIRTUAL_ENV each time.
          layout_venv() {
            export VIRTUAL_ENV="''${1:-.venv}"
            layout python3
          }
        '';
      };
    };

    home.file =
      mirrorDir ".config/fish/functions" "modules/shell/config/fish/functions"
      // mirrorDir ".config/fish/conf.d" "modules/shell/config/fish/conf.d"
      // {
        ".config/starship.toml".source = src "modules/shell/config/starship/starship.toml";
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
