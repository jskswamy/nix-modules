# Build the actual module's executables or data files without activating a home.
# nix build --impure --file tests/nvim-runtime.nix runtime
let
  nm = builtins.getFlake "path:${toString ../.}";
  hm = builtins.getFlake "github:nix-community/home-manager/4ac5a2ae9025eab1ebece4f9df8c315fd84a738a";
  pkgs = import nm.inputs.nixpkgs {
    system = builtins.currentSystem;
    config.allowUnfreePredicate = p: pkgs.lib.getName p == "terraform";
  };
  cfg =
    (hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        nm.homeManagerModules.tools.nvim
        {
          home.username = "test";
          home.homeDirectory = "/tmp/nvim-runtime-test";
          home.stateVersion = "24.05";
        }
      ];
    }).config;
in {
  runtime = pkgs.buildEnv {
    name = "nvim-runtime-test";
    paths = cfg.tools.nvim.runtimePackages ++ [cfg.tools.nvim.package];
    pathsToLink = ["/bin"];
  };
  data = pkgs.linkFarm "nvim-data-test" (map (name: {
    inherit name;
    path = cfg.xdg.dataFile."nvim/site/${name}".source;
  }) ["parser/latex.so" "parser-info/latex.revision" "queries/latex"]);
}
