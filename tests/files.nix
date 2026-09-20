# How many files each tool module writes, beyond what home-manager writes
# itself. Used to refresh the "Files" column of docs/tools.md.
# Run: nix eval --impure --json -f tests/files.nix
let
  hm = builtins.getFlake "github:nix-community/home-manager/4ac5a2ae9025eab1ebece4f9df8c315fd84a738a";
  nm = builtins.getFlake "path:${toString ../.}";
  pkgs = import nm.inputs.nixpkgs {system = builtins.currentSystem;};
  inherit (pkgs) lib;

  mk = modules:
    (hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules =
        [
          {
            home.username = "t";
            home.homeDirectory = "/home/t";
            home.stateVersion = "24.05";
          }
        ]
        ++ modules;
    }).config;

  base = builtins.attrNames (mk []).home.file;
  T = nm.homeManagerModules.tools;
in
  lib.mapAttrs
  (_: t: builtins.length (lib.subtractLists base (builtins.attrNames (mk [t]).home.file)))
  T
