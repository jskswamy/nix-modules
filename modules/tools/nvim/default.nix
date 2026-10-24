# Neovim (LazyVim). The whole config directory is symlinked, so edits take
# effect without a rebuild.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkSource mkToolEnable;
  src = mkSource config ./config "modules/tools/nvim/config";
  cfg = config.tools.nvim;
  latexGrammar = pkgs.vimPlugins.nvim-treesitter.builtGrammars.latex;
  treesitterSource = pkgs.fetchFromGitHub {
    owner = "nvim-treesitter";
    repo = "nvim-treesitter";
    rev = (lib.importJSON ./config/lazy-lock.json)."nvim-treesitter".commit;
    hash = "sha256-AMpRUNvTDUFx3EBc5POn3niPJlFRwG+Jgc1FR4CnXEk=";
  };
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.nvim = {
    enable = mkToolEnable lib "nvim";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.neovim;
      description = ''
        Package providing nvim, installed when this tool is enabled.

        Set to null to configure nvim without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };

    runtimePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        stdenv.cc
        tree-sitter
        git
        curl
        gnutar
        gzip
        unzip
        nodejs
        (python3.withPackages (ps: [ps.pip]))
        go
        ripgrep
        fd
        nil
        alejandra
        statix
        deadnix
        ((import ../../../pkgs/pkl.nix pkgs pkgs).pkl)
        jre_headless # Mason's pkl-lsp runs a Java archive.
        terraform
      ];
      description = ''
        Parser build tools, Mason runtimes, search utilities and configured
        Nix/Pkl/Terraform commands. Mason installs the remaining language
        servers, formatters and linters. Terraform requires allowing its
        unfree license. Override with [] to supply these tools externally.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package ++ cfg.runtimePackages;
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    home.shellAliases = {
      vim = "nvim";
      vi = "nvim";
    };

    home.file.".config/nvim".source = src.dir;

    # Generating LaTeX's parser exhausts small VMs; retain its parser and query revisions.
    xdg.dataFile = {
      "nvim/site/parser/latex.so".source = "${latexGrammar}/parser";
      "nvim/site/parser-info/latex.revision".text = latexGrammar.src.rev;
      "nvim/site/queries/latex".source = "${treesitterSource}/runtime/queries/latex";
    };
  };
}
