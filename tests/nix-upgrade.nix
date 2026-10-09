# Known-good fixtures from this repo's own pkgs/*.nix, asserted by
# tests/check.sh. Needs --impure, same as tests/integration.nix, for
# getFlake on the working tree.
let
  introspect = import ../pkgs/nix-upgrade/introspect.nix {
    flakePath = toString ../.;
    system = builtins.currentSystem;
  };
  byName = name: builtins.head (builtins.filter (e: e.name == name) introspect);
  hunk = byName "hunk";
  beads = byName "beads";
  moshiHook = byName "moshi-hook";
in {
  "hunk owner" = hunk.owner == "modem-dev";
  "hunk repo" = hunk.repo == "hunk";
  "hunk version present" = hunk.version != null;
  "beads owner" = beads.owner == "gastownhall";
  "beads repo" = beads.repo == "beads";
  "moshi-hook owner is null" = moshiHook.owner == null;
  "moshi-hook repo is null" = moshiHook.repo == null;
}
