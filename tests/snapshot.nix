# Evaluates the full tool set under home-manager and prints the parts of the
# result that integrations write into, as JSON. Run before and after a
# change and diff the two: the only differences allowed are the ones the
# change intends. Needs --impure, for getFlake on the working tree.
let
  hm = builtins.getFlake "github:nix-community/home-manager/4ac5a2ae9025eab1ebece4f9df8c315fd84a738a";
  nm = builtins.getFlake "path:${toString ../.}";
  pkgs = import nm.inputs.nixpkgs {system = builtins.currentSystem;};
  inherit (pkgs) lib;

  eval = extra:
    (hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        {
          home.username = "t";
          home.homeDirectory = "/home/t";
          home.stateVersion = "24.05";
        }
        extra
      ];
    }).config;

  # Lists whose order the module system does not promise are compared as sets.
  sorted = xs: lib.sort (a: b: a < b) xs;
  byDescription = cmds: lib.sort (a: b: (a.description or "") < (b.description or "")) cmds;

  full = eval {imports = [nm.homeManagerModules.default];};
in {
  gitSettings = full.programs.git.settings;
  lazygitSettings =
    full.programs.lazygit.settings
    // {customCommands = byDescription (full.programs.lazygit.settings.customCommands or []);};
  fishInit = full.programs.fish.interactiveShellInit;
  homeFiles = sorted (builtins.attrNames full.home.file);
  packages = sorted (map (p: p.name or "?") full.home.packages);
}
