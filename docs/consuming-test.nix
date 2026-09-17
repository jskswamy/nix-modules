let
  hm = builtins.getFlake "github:nix-community/home-manager/7834e82588860aaf780cec1366524456a70898d7";
  nm = builtins.getFlake "git+file:///home/subramk/sessions/nix-modules-split/nix-modules";
  pkgs = import (builtins.getFlake "github:nixos/nixpkgs/3ed67ec0a4d3c7ab4ae1f04f8ee8df07bfa506a2") {system = "x86_64-linux";};
  lib = pkgs.lib;
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
  T = nm.homeManagerModules.tools;
  pkgNames = c: map (p: p.name or "?") c.home.packages;
in {
  # A. enabling a tool installs it
  installsTool = let
    c = mk {imports = [T.nvim];};
  in {
    neovimInstalled = builtins.any (n: lib.hasPrefix "neovim" n) (pkgNames c);
  };
  # B. override which package
  overridePackage = let
    c = mk {
      imports = [T.tig];
      tools.tig.package = pkgs.hello;
    };
  in {
    gotHello = builtins.any (n: lib.hasPrefix "hello" n) (pkgNames c);
    noTig = !(builtins.any (n: lib.hasPrefix "tig" n) (pkgNames c));
  };
  # C. config-only: keep the config, install nothing
  configOnly = let
    c = mk {
      imports = [T.tig];
      tools.tig.package = null;
    };
  in {
    stillHasConfig = builtins.elem ".config/tig/config" (builtins.attrNames c.home.file);
    installsNothing = !(builtins.any (n: lib.hasPrefix "tig" n) (pkgNames c));
  };
  # D. override a settings value the module set with mkDefault
  overrideSetting = let
    c = mk {
      imports = [T.alacritty];
      programs.alacritty.settings.window.opacity = 0.8;
    };
  in {
    opacity = c.programs.alacritty.settings.window.opacity;
  };
  # E. replace a whole dotfile the module ships
  replaceFile = let
    c = mk {
      imports = [T.tig];
      home.file.".config/tig/config".text = lib.mkForce "# mine";
    };
  in {isMine = c.home.file.".config/tig/config".text;};
  # F. theme flows to every themeable tool
  theme = let
    c = mk {
      imports = [T.alacritty];
      theme.variant = "catppuccin";
    };
  in {
    alacrittyImport = builtins.head c.programs.alacritty.settings.general.import;
  };
  # G. package resolves even without the overlay applied
  overlayNotApplied = let
    c = mk {imports = [T.hunk];};
  in {
    hunkInstalled = builtins.any (n: lib.hasPrefix "hunk" n) (pkgNames c);
  };
}
