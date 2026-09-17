{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/herdr/config";
  cfg = config.tools.herdr;
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.herdr = {
    enable = mkToolEnable lib "herdr";

    projectsDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/Users/alice/dotfiles/herdr-projects";
      description = ''
        Absolute path to a directory of herdr-plus project definitions,
        symlinked onto herdr-plus's managed config dir.

        Project files pin absolute working directories of real
        repositories, so they are inventory rather than reusable
        configuration and this module ships none. Point this at wherever
        they are kept; leave it null to manage projects through
        herdr-plus itself.
      '';
    };
  };

  # activation.nix holds the herdr-lazy bootstrap and the launchd agent.
  # It is merged in here rather than imported so that it is gated by
  # tools.herdr.enable like everything else.
  config = lib.mkIf cfg.enable (lib.mkMerge [
    (import ./activation.nix {inherit config lib pkgs;})
    {
      home.file =
        {
          # herdr — terminal workspace manager for AI coding agents.
          ".config/herdr/config.toml".source = src.file "config.toml";

          # herdr-lazy plugin list — the path is herdr-lazy's own default
          # config dir (confirmed via `herdr plugin config-dir herdr-lazy`),
          # not a path herdr itself reads. See activation.nix for the script
          # that syncs against this file.
          ".config/herdr/plugins/config/herdr-lazy/plugins.list".source = src.file "plugins.list";

          # herdr-plus worktree auto-layouts — path is herdr-plus's own
          # managed config dir (confirmed via configBaseDir() in its Go
          # source, resolved through the HERDR_PLUGIN_CONFIG_DIR env var
          # herdr sets when invoking a plugin's commands — not the README's
          # dev-mode fallback path).
          ".config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees".source = src.file "herdr-plus/worktrees";

          # herdr-navigator config — path confirmed via
          # `herdr plugin config-dir herdr-navigator`. Remaps its Ctrl-A
          # agent filter shortcut off of herdr's own global ctrl+a prefix.
          ".config/herdr/plugins/config/herdr-navigator/config.toml".source = src.file "herdr-navigator/config.toml";
        }
        // lib.optionalAttrs (cfg.projectsDir != null) {
          ".config/herdr/plugins/config/cloudmanic.herdr-plus/projects".source =
            config.lib.file.mkOutOfStoreSymlink cfg.projectsDir;
        };
    }
  ]);
}
