{
  description = "Composable home-manager modules for per-tool configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = {nixpkgs, ...}: let
    inherit (nixpkgs) lib;

    systems = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = lib.genAttrs systems;

    # Every module here is a plain path, so a tool can import another tool
    # (its dependencies) and a group can import its tools, with the module
    # system deduplicating shared imports by path.
    dirNames = dir:
      builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir dir));

    tools = lib.genAttrs (dirNames ./modules/tools) (n: ./modules/tools + "/${n}");
    groups =
      lib.listToAttrs
      (map (f: lib.nameValuePair (lib.removeSuffix ".nix" f) (./modules/groups + "/${f}"))
        (builtins.attrNames (builtins.readDir ./modules/groups)));
  in {
    homeManagerModules =
      groups
      // {
        inherit tools;

        common = ./modules/_common;
        theme = ./modules/theme;

        # Every tool. Each one can still be switched off individually with
        # `tools.<name>.enable = false`.
        default.imports = builtins.attrValues tools;
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
