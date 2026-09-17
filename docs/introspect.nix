let
  hm = builtins.getFlake "github:nix-community/home-manager/7834e82588860aaf780cec1366524456a70898d7";
  nm = builtins.getFlake "git+file:///home/subramk/sessions/nix-modules-split/nix-modules";
  pkgs = import (builtins.getFlake "github:nixos/nixpkgs/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2") {system = "x86_64-linux";};
  lib = pkgs.lib;

  # A bare home-manager config with nothing imported, to subtract the
  # baseline files home-manager creates on its own.
  mk = extra:
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

  enabledPrograms = c:
    builtins.filter
    (n: let r = builtins.tryEval (c.programs.${n}.enable or false); in r.success && r.value)
    (builtins.attrNames c.programs);
  base = mk {};
  baseFiles = builtins.attrNames base.home.file;
  basePkgs = map (p: p.name or "?") base.home.packages;
  basePrograms = enabledPrograms base;

  describe = name: let
    c = mk {imports = [nm.homeManagerModules.tools.${name}];};
    files = lib.subtractLists baseFiles (builtins.attrNames c.home.file);
    pkgNames = lib.subtractLists basePkgs (map (p: p.name or "?") c.home.packages);
    declaredTools = builtins.attrNames c.tools;
  in {
    files = builtins.sort (a: b: a < b) files;
    programs = builtins.sort (a: b: a < b) (lib.subtractLists basePrograms (enabledPrograms c));
    packages = builtins.sort (a: b: a < b) pkgNames;
    pulls = builtins.filter (t: t != name) declaredTools;
    options =
      builtins.filter (o: o != "enable" && o != "_module")
      (builtins.attrNames (c.tools.${name} or {}));
  };
in
  lib.genAttrs (builtins.attrNames nm.homeManagerModules.tools) describe
