# Package definitions this repo owns, as a single nixpkgs overlay.
#
# Each file is an overlay in its own right, so a consumer that wants only
# one can import it directly instead of taking the whole set.
final: prev:
import ./beads.nix final prev
// import ./herdr.nix final prev
// import ./moshi-hook.nix final prev
// import ./claide.nix final prev
