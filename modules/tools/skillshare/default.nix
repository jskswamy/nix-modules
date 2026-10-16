# Skillshare: manages skills, plugin bundles, MCP and hooks across agents.
#
# Skillshare writes resolved versions, digests and bindings back into its
# config.yaml, so that file stays mutable and is never linked from the
# store. Activation only adds what is missing through the CLI (see
# reconcile.sh) and syncs; updates stay an explicit `skillshare update`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable ownPkg;
  inherit (lib) mkOption types;
  cfg = config.tools.skillshare;
  home = config.home.homeDirectory;

  entry = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Name Skillshare lists the entry under once added; its presence skips the add.";
      };
      args = mkOption {
        type = types.listOf types.str;
        description = "Noninteractive Skillshare CLI arguments that add the entry.";
      };
    };
  };
  entries = kind:
    mkOption {
      type = types.listOf entry;
      default = [];
      description = "${kind} to add when missing.";
    };

  profile = types.submodule {
    options = {
      agent = mkOption {
        type = types.str;
        description = "Skillshare agent this profile is an account of.";
      };
      configDir = mkOption {
        type = types.str;
        description = "The agent's config directory for this profile.";
      };
    };
  };

  # A profile named after its agent is that agent's built-in target, which
  # takes a skills path; any other is an account target, whose MCP, hook
  # and plugin state Skillshare writes under its own config directory.
  target = name: p:
    if name == p.agent
    then {
      inherit name;
      args = ["target" "add" name "${p.configDir}/skills"];
      dirs = ["${p.configDir}/skills"];
    }
    else {
      inherit name;
      args = ["target" "add" name "--agent" p.agent "--config-dir" p.configDir];
      dirs = [p.configDir];
    };

  declarations = {
    targets = lib.mapAttrsToList target cfg.profiles;
    # Plugin sync drives each agent's own CLI.
    agents = lib.unique (lib.mapAttrsToList (_: p: p.agent) cfg.profiles);
    inherit (cfg.resources) excludes skills plugins mcp hooks;
  };

  # Approved resource policy.
  #
  # Which agents can take each complete bundle comes from Skillshare's own
  # plugin discovery, recorded in fixtures/plugins.json. A bundle is bound
  # to every compatible target. Its skills also reach other targets through
  # the repository's standalone install, which compatible targets exclude,
  # so no target holds both copies of a skill.
  compat = (lib.importJSON ./fixtures/plugins.json).plugins;
  jskswamyBundles = ["codebase" "commit-tools" "craft" "devenv" "jot" "refactor" "sketch-note" "study" "typst-notes"];
  # Skillshare package name -> source. Stable Superpowers is the default
  # branch of obra/superpowers; superpowers-dev is its `dev` ref. The
  # official marketplace lists Matt Pocock's skills as an external source,
  # which Skillshare takes only from its own repository.
  bundles =
    {
      ponytail = "DietrichGebert/ponytail";
      superpowers = "obra/superpowers";
      beads = "steveyegge/beads";
      context7 = "anthropics/claude-plugins-official";
      gopls-lsp = "anthropics/claude-plugins-official";
      mattpocock-skills = "mattpocock/skills";
    }
    // lib.genAttrs jskswamyBundles (_: "jskswamy/skills");

  profileNames = builtins.attrNames cfg.profiles;
  ofAgent = agents: builtins.filter (t: builtins.elem cfg.profiles.${t}.agent agents) profileNames;
  bundleTargets = name: ofAgent compat.${name}.agents;
  targetArgs = lib.concatMap (t: ["--target" t]);
  claudeTargets = ofAgent ["claude"];

  plugins =
    lib.mapAttrsToList (name: source: {
      inherit name;
      args = ["plugin" "add" source "--plugin" name] ++ targetArgs (bundleTargets name) ++ ["--json"];
    })
    bundles;

  excludes = lib.filterAttrs (_: v: v != []) (lib.genAttrs profileNames (t:
    lib.concatMap (name: compat.${name}.skills or [])
    (builtins.filter (name: builtins.elem t (bundleTargets name)) (builtins.attrNames bundles))));

  skills =
    # bivouac and release sit in no approved bundle, so every target
    # needs this install. It installs the whole repository at once, so
    # `release` only stands in for it: once listed, the install is done.
    [
      {
        name = "release";
        args = ["install" "jskswamy/skills/skills" "--kind" "skill" "--all" "-y"];
      }
    ]
    ++ lib.optional (bundleTargets "beads" != profileNames) {
      name = "beads";
      args = ["install" "steveyegge/beads/plugins/beads/skills/beads" "-y"];
    }
    # The repository holds more skills than its bundle; select exactly the
    # bundle's (`--skill` is noninteractive and refuses `-y`).
    ++ lib.optional (bundleTargets "mattpocock-skills" != profileNames) {
      name = "setup-matt-pocock-skills";
      args = ["install" "mattpocock/skills" "--skill" (lib.concatStringsSep "," compat.mattpocock-skills.skills)];
    };

  mcpAdd = name: targets: rest: {
    inherit name;
    args = ["mcp" "add" name] ++ targetArgs targets ++ rest;
  };
  mcp = lib.mapAttrsToList (name: s: mcpAdd name s.profiles s.args) cfg.mcpServers;
  unknownMcpProfiles = lib.concatLists (lib.mapAttrsToList (name: s:
    map (p: "${name} -> ${p}") (builtins.filter (p: !(cfg.profiles ? ${p})) s.profiles))
  cfg.mcpServers);

  mcpServer = types.submodule {
    options = {
      profiles = mkOption {
        type = types.listOf types.str;
        default = profileNames;
        defaultText = lib.literalMD "every profile in `tools.skillshare.profiles`";
        description = "Profiles (target names) the server is added to.";
      };
      args = mkOption {
        type = types.listOf types.str;
        description = ''
          `skillshare mcp add` arguments after the target flags:
          `["--url" URL]` for an HTTP server, `["--" COMMAND ARGS...]` for stdio.
        '';
      };
    };
  };

  # Defaults at mkDefault per field, so a consumer adds names alongside
  # them, or overrides one field, without restating the rest.
  defaults = lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault));

  # RTK contributes its command-rewrite hook only. Pi is left out: its
  # Skillshare hooks take code, not events, and `rtk hook` has no pi mode.
  rtkHook = builtins.toFile "skillshare-rtk-hook.json" (builtins.toJSON {
    bindings = lib.genAttrs claudeTargets (_: {
      events.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "rtk hook claude";
            }
          ];
        }
      ];
    });
  });
  hooks = lib.optional (claudeTargets != []) {
    name = "rtk";
    args = ["hooks" "add" "rtk" "--file" rtkHook];
  };

  skillshare =
    if cfg.package != null
    then lib.getExe cfg.package
    else "skillshare";
in {
  options.tools.skillshare = {
    declarations = mkOption {
      internal = true;
      readOnly = true;
      default = declarations;
      description = "Everything activation hands reconcile.sh.";
    };

    enable = mkToolEnable lib "skillshare";

    package = mkOption {
      type = types.nullOr types.package;
      default = ownPkg pkgs "skillshare";
      description = ''
        Package providing skillshare, installed when this tool is enabled.

        Set to null to reconcile with a skillshare found on PATH instead.
      '';
    };

    syncOnActivation = mkOption {
      type = types.bool;
      default = true;
      description = "Run `sync --all` and `sync plugins` after reconciling on activation.";
    };

    profiles = mkOption {
      type = types.attrsOf profile;
      example = lib.literalExpression ''
        {
          claude-extra = {
            agent = "claude";
            configDir = "''${config.home.homeDirectory}/.claude-extra";
          };
        }
      '';
      description = ''
        Agent profiles Skillshare targets, keyed by target name.

        Defaults to `claude` (~/.claude) and `pi` (~/.pi/agent). Names you
        define are added alongside them. A name equal to its `agent` is that
        agent's built-in target (skills under `configDir/skills`); any other
        name is an account target, added with
        `--agent AGENT --config-dir CONFIGDIR`. Use `lib.mkForce` on the
        whole set to drop the defaults.
      '';
    };

    mcpServers = mkOption {
      type = types.attrsOf mcpServer;
      example = lib.literalExpression ''
        {
          extra = {
            profiles = ["claude-extra"];
            args = ["--url" "https://mcp.example.com/mcp"];
          };
        }
      '';
      description = ''
        MCP servers to add, keyed by name, each to the profiles it lists.

        Defaults to `time`, `chrome-devtools` and, with
        `enableAgentgateway`, `agentgateway`, each on every profile. Names
        you define are added alongside them. Context7 comes with its plugin
        bundle, not from here.

        An entry is added only while Skillshare does not list its name;
        activation never refreshes it afterwards. Changing `args` or
        `profiles` of an existing server (a new Chrome DevTools pin, the
        gateway port, another time package) needs `skillshare mcp remove
        NAME` first.
      '';
    };

    timeServerPackage = mkOption {
      type = types.nullOr types.package;
      default = pkgs.mcp-server-time;
      defaultText = lib.literalExpression "pkgs.mcp-server-time";
      description = ''
        Package installed for the `time` MCP server. It is registered by its
        stable profile path, `home.profileDirectory/bin/mcp-server-time`, so
        upgrades need no re-registration. Set to null to provide that binary
        in the profile some other way.
      '';
    };

    enableAgentgateway = mkOption {
      type = types.bool;
      # The AgentGateway daemon runs only as a Darwin launchd agent.
      default = pkgs.stdenv.hostPlatform.isDarwin;
      description = ''
        Whether to register the local AgentGateway MCP endpoint. Like every
        MCP entry it is set once; a later port change is not re-registered.
      '';
    };

    resources = {
      excludes = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = {};
        description = "Skill exclude patterns to add to each target when missing.";
      };
      skills = entries "Skill installs";
      plugins = entries "Plugins";
      mcp = entries "MCP servers";
      hooks = entries "Hook entries";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.filter (p: p != null) [cfg.package cfg.timeServerPackage];

    assertions = [
      {
        assertion = unknownMcpProfiles == [];
        message = "tools.skillshare.mcpServers lists unknown profiles: ${lib.concatStringsSep ", " unknownMcpProfiles}";
      }
    ];

    tools.skillshare = {
      profiles = defaults {
        claude = {
          agent = "claude";
          configDir = "${home}/.claude";
        };
        pi = {
          agent = "pi";
          configDir = "${home}/.pi/agent";
        };
      };

      mcpServers = defaults ({
          time.args = ["--" "${config.home.profileDirectory}/bin/mcp-server-time"];
          chrome-devtools.args = ["--" "npx" "-y" "chrome-devtools-mcp@1.11.0" "--browser-url" "http://localhost:9222"];
        }
        // lib.optionalAttrs cfg.enableAgentgateway {
          agentgateway.args = ["--url" "http://127.0.0.1:${toString (config.tools.agentgateway.port or 3050)}/mcp"];
        });

      resources = {inherit excludes skills plugins mcp hooks;};
    };

    # Failure warns instead of aborting the rest of activation; reconcile
    # still attempts every step before reporting it. The agent CLIs that
    # plugin installs drive come from the freshly installed profile.
    home.activation.skillshare = lib.hm.dag.entryAfter ["writeBoundary" "linkGeneration" "installPackages"] ''
      if [[ -v DRY_RUN ]]; then
        verboseEcho "Skipping skillshare reconcile in dry run"
      else
        XDG_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome} \
        PATH=${lib.makeBinPath [pkgs.jq pkgs.coreutils pkgs.gnugrep]}:${config.home.profileDirectory}/bin:$PATH \
          ${pkgs.bash}/bin/bash ${./reconcile.sh} ${lib.escapeShellArg skillshare} ${pkgs.writeText "skillshare-declarations.json" (builtins.toJSON declarations)} \
          ${lib.optionalString (!cfg.syncOnActivation) "--no-sync"} ||
          warnEcho "skillshare reconcile reported failures; see the warnings above"
      fi
    '';
  };
}
