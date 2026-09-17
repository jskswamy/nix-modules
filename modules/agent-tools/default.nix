# Tooling for AI coding agents: herdr, Claude Code, MCP, ccstatusline,
# beads, fabric, pet.
{self}: {
  config,
  lib,
  ...
}: let
  inherit (import ../../lib) mkSource;
  src = mkSource config self;
  cfg = config.agentTools;
in {
  imports = [
    ../_common
    ../theme
    # Carried verbatim: activation scripts and launchd agents, which are
    # logic rather than config and are easier to review unchanged.
    ./herdr.nix
    ./mcp.nix
  ];

  # Claude Code's settings.json and the 1mcp server list are not shipped
  # here: both pin absolute paths under a specific user's home directory,
  # which makes them machine-specific rather than reusable. A consumer
  # provides its own.

  options.agentTools.herdr.projectsDir = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/Users/alice/dotfiles/herdr-projects";
    description = ''
      Absolute path to a directory of herdr-plus project definitions,
      symlinked onto herdr-plus's managed config dir.

      Project files pin absolute working directories of real repositories,
      so they are inventory rather than reusable configuration and this
      module ships none. Point this at wherever they are kept; leave it
      null to manage projects through herdr-plus itself.
    '';
  };

  config.home.file =
    {
      # Beads memory system
      ".config/bd/config.yaml".source = src "modules/agent-tools/config/beads/config.yaml";

      ".config/pet/config.toml".source = src "modules/agent-tools/config/pet/config.toml";
      ".config/pet/snippet.toml".source = src "modules/agent-tools/config/pet/snippet.toml";

      # Fabric patterns — individually symlinked so fabric keeps managing
      # the rest of its pattern directory itself.
      ".config/fabric/patterns/conventional_commit".source = src "modules/agent-tools/config/fabric/patterns/conventional_commit";
      ".config/fabric/patterns/git_status_summary".source = src "modules/agent-tools/config/fabric/patterns/git_status_summary";
      ".config/fabric/patterns/homework_commit".source = src "modules/agent-tools/config/fabric/patterns/homework_commit";
      ".config/fabric/patterns/semantic_commit".source = src "modules/agent-tools/config/fabric/patterns/semantic_commit";

      ".config/ccstatusline/settings.json".source = src "modules/agent-tools/config/ccstatusline/settings.json";

      # herdr — terminal workspace manager for AI coding agents.
      ".config/herdr/config.toml".source = src "modules/agent-tools/config/herdr/config.toml";

      # herdr-lazy plugin list — the path is herdr-lazy's own default config
      # dir (confirmed via `herdr plugin config-dir herdr-lazy`), not a path
      # herdr itself reads. See herdr.nix for the activation script that
      # syncs against this file.
      ".config/herdr/plugins/config/herdr-lazy/plugins.list".source = src "modules/agent-tools/config/herdr/plugins.list";

      # herdr-plus worktree auto-layouts — path is herdr-plus's own managed
      # config dir (confirmed via configBaseDir() in its Go source, resolved
      # through the HERDR_PLUGIN_CONFIG_DIR env var herdr sets when invoking
      # a plugin's commands — not the README's dev-mode fallback path).
      ".config/herdr/plugins/config/cloudmanic.herdr-plus/worktrees".source = src "modules/agent-tools/config/herdr/herdr-plus/worktrees";

      # herdr-navigator config — path confirmed via
      # `herdr plugin config-dir herdr-navigator`. Remaps its Ctrl-A agent
      # filter shortcut off of herdr's own global ctrl+a prefix.
      ".config/herdr/plugins/config/herdr-navigator/config.toml".source = src "modules/agent-tools/config/herdr/herdr-navigator/config.toml";

      # MCP configuration (AgentGateway server definitions)
      ".config/agentgateway/config.yaml".source = src "modules/agent-tools/config/mcp/config.yaml";
    }
    // lib.optionalAttrs (cfg.herdr.projectsDir != null) {
      ".config/herdr/plugins/config/cloudmanic.herdr-plus/projects".source =
        config.lib.file.mkOutOfStoreSymlink cfg.herdr.projectsDir;
    };
}
