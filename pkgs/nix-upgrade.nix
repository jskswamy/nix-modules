# pkgs/nix-upgrade.nix
#
# Harness-agnostic CLI for checking/upgrading this flake's overlay packages
# and flake inputs. Delegates the hard part (version/hash bump, including
# vendorHash/cargoHash) to the real upstream nix-update; this tool only adds
# discovery (no hardcoded package table) and flake-input bumps.
final: prev: {
  nix-upgrade = prev.writeShellApplication {
    name = "nix-upgrade";
    runtimeInputs = with prev; [nix-update gh jq gum git];
    text =
      ''
        export NIX_UPGRADE_INTROSPECT_NIX=${./nix-upgrade/introspect.nix}
      ''
      + builtins.readFile ./nix-upgrade/nix-upgrade.sh;
  };
}
