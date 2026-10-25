{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../../../lib) mkToolEnable;
  cfg = config.tools.mergiraf;

  # Output of `mergiraf languages --gitattributes`, kept as a pure Nix list so
  # evaluation stays free of import-from-derivation and works when package = null.
  gitattributes = [
    "*.java merge=mergiraf"
    "*.properties merge=mergiraf"
    "*.kt merge=mergiraf"
    "*.kts merge=mergiraf"
    "*.rs merge=mergiraf"
    "*.go merge=mergiraf"
    "go.mod merge=mergiraf"
    "go.sum merge=mergiraf"
    "go.work.sum merge=mergiraf"
    "*.ini merge=mergiraf"
    "*.js merge=mergiraf"
    "*.jsx merge=mergiraf"
    "*.mjs merge=mergiraf"
    "*.cjs merge=mergiraf"
    "*.json merge=mergiraf"
    "*.yml merge=mergiraf"
    "*.yaml merge=mergiraf"
    "pyproject.toml merge=mergiraf"
    "*.toml merge=mergiraf"
    "*.html merge=mergiraf"
    "*.htm merge=mergiraf"
    "*.xhtml merge=mergiraf"
    "*.xml merge=mergiraf"
    "*.c merge=mergiraf"
    "*.h merge=mergiraf"
    "*.cc merge=mergiraf"
    "*.hh merge=mergiraf"
    "*.cpp merge=mergiraf"
    "*.hpp merge=mergiraf"
    "*.cxx merge=mergiraf"
    "*.hxx merge=mergiraf"
    "*.c++ merge=mergiraf"
    "*.h++ merge=mergiraf"
    "*.mpp merge=mergiraf"
    "*.cppm merge=mergiraf"
    "*.ixx merge=mergiraf"
    "*.tcc merge=mergiraf"
    "*.cs merge=mergiraf"
    "*.dart merge=mergiraf"
    "*.dts merge=mergiraf"
    "*.scala merge=mergiraf"
    "*.sbt merge=mergiraf"
    "*.scm merge=mergiraf"
    "*.ts merge=mergiraf"
    "*.mts merge=mergiraf"
    "*.cts merge=mergiraf"
    "*.tsx merge=mergiraf"
    "*.py merge=mergiraf"
    "*.php merge=mergiraf"
    "*.phtml merge=mergiraf"
    "*.php3 merge=mergiraf"
    "*.php4 merge=mergiraf"
    "*.php5 merge=mergiraf"
    "*.phps merge=mergiraf"
    "*.phpt merge=mergiraf"
    "*.sol merge=mergiraf"
    "*.lua merge=mergiraf"
    "*.rb merge=mergiraf"
    "*.ex merge=mergiraf"
    "*.exs merge=mergiraf"
    "*.nix merge=mergiraf"
    "*.sv merge=mergiraf"
    "*.svh merge=mergiraf"
    "*.md merge=mergiraf"
    "*.hcl merge=mergiraf"
    "*.tf merge=mergiraf"
    "*.tfvars merge=mergiraf"
    "*.ml merge=mergiraf"
    "*.mli merge=mergiraf"
    "*.hs merge=mergiraf"
    "*.mk merge=mergiraf"
    "Makefile merge=mergiraf"
    "GNUmakefile merge=mergiraf"
    "*.bzl merge=mergiraf"
    "*.bxl merge=mergiraf"
    "*.bazel merge=mergiraf"
    "*.star merge=mergiraf"
    "*.sky merge=mergiraf"
    "BUILD merge=mergiraf"
    "WORKSPACE merge=mergiraf"
    "BUCK merge=mergiraf"
    "PACKAGE merge=mergiraf"
    "*.cmake merge=mergiraf"
    "CMakeLists.txt merge=mergiraf"
    "*.f merge=mergiraf"
    "*.for merge=mergiraf"
    "*.f90 merge=mergiraf"
    "*.R merge=mergiraf"
    "*.r merge=mergiraf"
    ".Rprofile merge=mergiraf"
    "requirements.txt merge=mergiraf"
    "requirements-dev.txt merge=mergiraf"
    "requirements-docs.txt merge=mergiraf"
    "requirements-test.txt merge=mergiraf"
    "*.sh merge=mergiraf"
    "*.bash merge=mergiraf"
    "PKGBUILD merge=mergiraf"
    "*.gleam merge=mergiraf"
    "*.erl merge=mergiraf"
    "*.hrl merge=mergiraf"
    "*.escript merge=mergiraf"
    "*.m merge=mergiraf"
    "*.qml merge=mergiraf"
  ];
in {
  imports = [
    ../../_common
    ../../theme
  ];

  options.tools.mergiraf = {
    enable = mkToolEnable lib "mergiraf";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.mergiraf;
      description = ''
        Package providing mergiraf, installed when this tool is enabled.

        Set to null to configure mergiraf without installing it — for a
        binary that comes from the system, Homebrew, or a language
        package manager instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.optional (cfg.package != null) cfg.package;

    # mergiraf is wired into git from here, not the other way round:
    # enabling mergiraf registers the syntax-aware merge driver and
    # associates all supported file extensions in global gitattributes.
    programs.git = {
      attributes = gitattributes;
      settings.merge.mergiraf = {
        name = lib.mkDefault "mergiraf";
        driver = lib.mkDefault "mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
      };
    };
  };
}
