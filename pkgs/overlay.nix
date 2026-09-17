# Package definitions this repo owns, as a single nixpkgs overlay.
#
# These are tools that are not in nixpkgs, but that this repo configures —
# a module that configures a tool it cannot install would leave the
# consumer to repackage it themselves. Each file is an overlay in its own
# right, so a consumer that wants only one can import it directly.
final: prev:
import ./beads.nix final prev
// import ./ccstatusline.nix final prev
// import ./herdr.nix final prev
// import ./hunk.nix final prev
// import ./moshi-hook.nix final prev
// import ./claide.nix final prev
