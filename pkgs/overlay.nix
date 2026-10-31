# Package definitions this repo owns, as a single nixpkgs overlay.
#
# These are tools that are not in nixpkgs, but that this repo configures —
# a module that configures a tool it cannot install would leave the
# consumer to repackage it themselves. Each file is an overlay in its own
# right, so a consumer that wants only one can import it directly.
final: prev:
import ./agentgateway.nix final prev
// import ./aide.nix final prev
// import ./antigravity-cli.nix final prev
// import ./beads.nix final prev
// import ./ccstatusline.nix final prev
// import ./codex.nix final prev
// import ./codebase-memory-mcp.nix final prev
// import ./things-cloud-mcp.nix final prev
// import ./tala.nix final prev
// import ./gastown.nix final prev
// import ./feather-font.nix final prev
// import ./entire.nix final prev
// import ./herdr.nix final prev
// import ./hunk.nix final prev
// import ./moshi-hook.nix final prev
// import ./nix-upgrade.nix final prev
// import ./rtk.nix final prev
// import ./pkl.nix final prev
// import ./skillshare.nix final prev
// import ../overlays/opencode.nix final prev
// {
  pi-coding-agent = final.callPackage ./pi-coding-agent.nix {};
  vim-full =
    if prev.stdenv.hostPlatform.isDarwin
    then prev.vim
    else prev.vim-full;
}
