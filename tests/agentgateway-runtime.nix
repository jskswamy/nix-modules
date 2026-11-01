let
  nm = builtins.getFlake "path:${toString ../.}";
  hm = builtins.getFlake "github:nix-community/home-manager/4ac5a2ae9025eab1ebece4f9df8c315fd84a738a";
  pkgs = import nm.inputs.nixpkgs {
    system = builtins.currentSystem;
    overlays = [nm.overlays.default];
  };
  c =
    (hm.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        nm.homeManagerModules.tools.agentgateway
        {
          home.username = "t";
          home.homeDirectory = "/home/t";
          home.stateVersion = "24.05";
          tools.agentgateway.registerMcp = false;
        }
      ];
    }).config;
  hook =
    c.home.activation.agentgatewaySessionKey or {
      data = "";
      before = [];
      after = [];
    };
in {
  inherit (hook) data before after;
  wrapper = pkgs.lib.replaceStrings ["exec ${pkgs.agentgateway}/bin/agentgateway -f"] ["printf 'gateway-started\\n'; exit 0; #"] (pkgs.lib.last c.launchd.agents.agentgateway.config.ProgramArguments);
}
