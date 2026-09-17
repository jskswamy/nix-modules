{
  description = "Composable home-manager modules for per-tool configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;

    # Groups whose module is a function of `self` (they reference files in
    # this flake's own source tree). `_common` and `theme` are plain paths
    # so that the module system can deduplicate them by path when several
    # groups import them at once.
    groups = [
      "shell"
      "terminal"
      "editor"
    ];

    groupModules =
      nixpkgs.lib.genAttrs groups
      (g: import (./modules + "/${g}") {inherit self;});
  in {
    homeManagerModules =
      groupModules
      // {
        common = ./modules/_common;
        theme = ./modules/theme;

        # Everything at once. Consumers that want a subset should import
        # the individual group modules instead.
        default.imports =
          [
            ./modules/_common
            ./modules/theme
          ]
          ++ builtins.attrValues groupModules;
      };

    overlays.default = import ./pkgs/overlay.nix;

    packages = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        import ./pkgs/overlay.nix pkgs pkgs
    );

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
