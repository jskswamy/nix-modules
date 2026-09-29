{
  config,
  lib,
  ...
}: let
  cfg = config.programs.bivouac;
  inherit (lib) concatMapStringsSep concatStringsSep literalExpression mkEnableOption mkOption types;

  pklString = builtins.toJSON;
  indent = prefix: text:
    concatStringsSep "\n" (map (line: prefix + line) (lib.splitString "\n" text));

  pklValue = value:
    if builtins.isString value
    then pklString value
    else if builtins.isBool value
    then
      if value
      then "true"
      else "false"
    else if builtins.isInt value
    then toString value
    else if builtins.isList value
    then ''new Listing { ${concatStringsSep "; " (map pklValue value)} }''
    else throw "programs.bivouac: unsupported settings value";

  renderListing = name: values: ''
    ${name} {
    ${concatMapStringsSep "\n" (value: "  ${pklString value}") values}
    }
  '';

  renderSettings = settings: ''
    settings {
    ${concatMapStringsSep "\n" (name: "  [${pklString name}] = ${pklValue settings.${name}}") (builtins.attrNames settings)}
    }
  '';

  renderPane = pane: ''
    new HerdrPane { label = ${pklString pane.label}${lib.optionalString (pane.command != null) "; command = ${pklString pane.command}"} }
  '';

  renderTab = tab: ''
    new HerdrTab {
      label = ${pklString tab.label}
      panes {
    ${indent "    " (concatMapStringsSep "\n" renderPane tab.panes)}
      }
    }
  '';

  moduleList = cfg.nixModules.modules ++ cfg.nixModules.extraModules;
  packageList = cfg.packages ++ cfg.extraPackages;
  settings =
    cfg.settings
    // cfg.extraSettings
    // {"nixModules.workspaceRoot" = cfg.nixModules.workspaceRoot;};

  basePkl = ''
    template = ${pklString cfg.template}
    region = ${pklString cfg.region}
    size = ${pklString cfg.size}

    ${renderListing "sshKeys" cfg.sshKeys}

    ${renderListing "instructions" cfg.instructions}

    // The personal configuration every instance gets from nix-modules. Tools
    // are named one by one rather than through larger groups so cloud instances
    // avoid desktop terminals, local signing requirements, and duplicate agent
    // support packages.
    flakes {
      new Flake {
        url = ${pklString cfg.nixModules.url}
        packages {}
        modules {
    ${concatMapStringsSep "\n" (module: "      ${pklString module}") moduleList}
        }
      }
    }

    // Git identity is intentionally not set here. Let the consumer's Git
    // identity and path-based include rules decide name, email, and signing.
    ${renderSettings settings}

    // Tools the nix-modules fish config and interactive helpers expect on a
    // minimal instance. Project configs can add to this with extraPackages.
    ${renderListing "packages" packageList}

    ${renderListing "agents" cfg.agents}

    // Laid out by `bivouac herdr` in every session's workspace. A project that
    // declares a tab with the same label keeps its own; the first declaration
    // wins and the later one is skipped.
    herdrTabs {
    ${indent "  " (concatMapStringsSep "\n" renderTab cfg.herdrTabs)}
    }
  '';

  settingsType = types.attrsOf (types.oneOf [types.str types.bool types.int (types.listOf types.str)]);
  paneType = types.submodule {
    options = {
      label = mkOption {type = types.str;};
      command = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };
  tabType = types.submodule {
    options = {
      label = mkOption {type = types.str;};
      panes = mkOption {type = types.listOf paneType;};
    };
  };
in {
  imports = [../../_common];

  options.programs.bivouac = {
    enable = mkEnableOption "Bivouac base configuration";

    template = mkOption {
      type = types.str;
      default = "docker";
    };

    region = mkOption {
      type = types.str;
      default = "blr1";
    };

    size = mkOption {
      type = types.str;
      default = "s-2vcpu-4gb";
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Machine-specific SSH key fingerprints allowed into instances.";
    };

    instructions = mkOption {
      type = types.listOf types.str;
      default = ["workflow.md"];
    };

    nixModules = {
      url = mkOption {
        type = types.str;
        default = "github:jskswamy/nix-modules";
      };

      workspaceRoot = mkOption {
        type = types.str;
        default = "sessions";
        description = "Value rendered to nixModules.workspaceRoot in Bivouac instances.";
      };

      modules = mkOption {
        type = types.listOf types.str;
        default = [
          "tools.fish"
          "tools.starship"
          "tools.direnv"
          "tools.nvim"
          "tools.vim"
          "tools.tmux"
          "tools.tmuxp"
          "tools.lazygit"
          "tools.tig"
          "tools.hunk"
          "tools.ccstatusline"
          "tools.aide"
          "tools.codebase-memory-mcp"
        ];
      };

      extraModules = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional nix-modules home-manager module paths to import.";
      };
    };

    settings = mkOption {
      type = settingsType;
      default = {
        "programs.git.enable" = true;
        "tools.ccstatusline.claude.enable" = true;
        "tools.codebase-memory-mcp.registerMcp" = true;
      };
      example = literalExpression ''{"tools.example.enable" = true;}'';
      description = "Generic Home Manager option overrides for Bivouac instances. Do not set Git identity here; keep it in the consumer's Git identity module.";
    };

    extraSettings = mkOption {
      type = settingsType;
      default = {};
      description = "Additional Home Manager option overrides merged over settings.";
    };

    packages = mkOption {
      type = types.listOf types.str;
      default = [
        "eza"
        "bat"
        "difftastic"
        "ripgrep"
        "fd"
        "fzf"
        "zoxide"
        "jump"
        "any-nix-shell"
        "git-lfs"
        "git-lfs-transfer"
      ];
    };

    extraPackages = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional nixpkgs package names installed on Bivouac instances.";
    };

    agents = mkOption {
      type = types.listOf types.str;
      default = ["claude"];
    };

    herdrTabs = mkOption {
      type = types.listOf tabType;
      default = [
        {
          label = "agent";
          panes = [{label = "agent";}];
        }
        {
          label = "lazygit";
          panes = [
            {
              label = "lazygit";
              command = "lazygit";
            }
          ];
        }
        {
          label = "editor";
          panes = [
            {
              label = "editor";
              command = "nvim .";
            }
            {label = "term";}
          ];
        }
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    home.file.".config/bivouac/base.pkl".text = basePkl;
  };
}
